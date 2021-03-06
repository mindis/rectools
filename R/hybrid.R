#predict using the k nearest neighbour from the "basis" of the user-space(origData)
# covariates (e.g. age, gender) and item type preferences (e.g.
# preferred movie genres) are allowed

########################## predict() function ##########################

# predict newData argument from origData argument using the hybrid kNN-Matrix Product Method

# arguments:

#    datain: training set, object of class 'usrData' (see file
#    findUsrItmData.R)
#    newData: data point (just one for now) to be predicted, object of
#             class 'usrDatum'
#    newItem: ID of the item rating to be predicted for the user in
#             newData
#    wtcovs: weight to put on covariates; NULL if no covs
#    wtcats: weight to put on item categories; NULL if no cats
#    k: a list of the number of nearest neigbhors to be considered while predicting
#    r: rank for factorisation

# value:

#    predicted ratings for newData

hybdpredict.usrData <- function(datain,newData,newItem,
                                k,r, wtcovs=NULL,wtcats=NULL) {
  
  origData <- formUserData(datain)
  #getting the "basis" matix of the "user space"
  if (r >= min(dim(origData))) {
    stop('no data on this item')
  }
  else{
    appMatrix = Reco()
    train_set = data_memory(unlist(datain[1]), unlist(datain[2]),
                            unlist(datain[3]), index1 = TRUE)
    appMatrix$train(train_set)
    #get factors after NMF -- need to use $tune() fix later
    factors <- appMatrix$output(out_memory(), out_memory())
    #P- is the "user space basis"-- see RecoSys for P and Q
    P <- factors$P
    usrs <- rep(1:dim(P)[1], each = dim(P)[2])
    itms <- rep.int(1:dim(P)[2], dim(P)[1])
    #get ratings from "user space basis"
    rtngs <- as.vector(t(P))
    #form basis (is of type usrData)
    basis <- formUserData(data.frame(usrs, itms, rtngs))
  }
  
  # action of checkNewItem(): here oneUsr is one representative-user record in
  # the "basis" of the use-space; 
  #the function will check which item in the record, if any,
  # equals newItem, and will return that value and the corresponding
  # rating; defined for use by sapply() below
  checkNewItem <- function(oneUsr) {
    #itms <- as.list(as.data.frame(t(oneUsr$itms)))
    tmp <- match(oneUsr$itms[[1]], newItem) 
    if (all(is.na(tmp))) {
      c(NA, NA)
    }
    else
    {
      whichOne <- which(!is.na(tmp))
      c(whichOne,oneUsr$ratings[whichOne])
    }
  }
  found <- as.matrix(sapply(basis,checkNewItem))
  # found is of dimensions 2 x number of users;
  # found[1,i] = j means origData[[i]]$itms[j] = newItem;
  # found[1,i] = NA means newItem wasn't rated by user i;ß
  # found[2,i] will be the rating in the non-NA case
  # we need to get rid of the NA users 
  whoHasIt <- which(!is.na(found[1,]))
  # whoHasIt[i] is the index, i.e. user ID, of the i-th user who has
  # rated newData
  if (is.null(whoHasIt) | length(whoHasIt)==0) return(NA)  # no one rated this item
  basis <- basis[whoHasIt]  
  # now basis only has the relevant users, the ones who have rated
  # newItem, so select only those columns of the found matrix
  found <- found[,whoHasIt,drop=FALSE]
  #found <- found[!is.na(found)]
  # find the distance from newData to one user y of origData; defined for
  # use in sapply() below
  onecos <- function(y) cosDist(newData,y,wtcovs,wtcats)
  cosines <- sapply(basis,onecos) 
  # the vector cosines contains the distances from newData to all the
  # original data points;
  
  #action of findKnghbourRtng(): predict rating based on each k[i] neighbours
  #x = k[i]
  #if x > neighbours present in the dataset, then the maximum number of meighbours is used
  findKnghbourRtng <- function(x){
    #x can be atmost the number of neighbours in the dataset
    x <- min(x, length(cosines))
    #klarge is a vector containing the indices of the x closest neighbours
    klarge <- order(cosines,decreasing=TRUE)[1:x]
    mean(as.numeric(found[2, klarge]))
  }
  sapply(k, findKnghbourRtng)
}

# duplicate!
# cosDist() find cosine distance between x and y, elements of an object
# of 'usrData' class; only items rated in both x and y are used; if none
# exist, then return NaN
### cosDist <- function(x,y,wtcovs,wtcats) {
###   # rated items in common
###   commItms <- intersect(x$itms[[1]],y$itms[[1]])
###   if (is.null(commItms)| length(commItms)==0) return(NaN)
###   # where are they in x and y?
###   xwhere <- which(!is.na(match(x$itms[[1]],commItms)))
###   ywhere <- which(!is.na(match(y$itms[[1]],commItms)))
###   xrats <- x$ratings[xwhere,]
###   yrats <- y$ratings[ywhere,]
###   cosTot <- xrats[[1]] %*% yrats[[1]]
###   xl2 <- sum(xrats^2)
###   yl2 <- sum(yrats^2)
###   if (!is.null(wtcovs)) {
###     cosTot <- cosTot + wtcovs * x$cvrs %*% y$cvrs
###     xl2 <- xl2 + sum((wtcovs*x$cvrs)^2)
###     yl2 <- yl2 + sum((wtcovs*y$cvrs)^2)
###   }
###   if (!is.null(wtcats)) {
###     cosTot <- cosTot + wtcats * x$cats %*% t(y$cats)
###     xl2 <- xl2 + sum((wtcovs*x$cats)^2)
###     yl2 <- yl2 + sum((wtcovs*y$cats)^2)
###   }
###   cosTot / sqrt(xl2 * yl2)
### }
