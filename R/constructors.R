# constructors.R - Constructor methods for fwdControl
# FLasher/R/constructors.R

# Copyright European Union, 2016
# Author: Iago Mosqueira (EC JRC) <iago.mosqueira@ec.europa.eu>
#
# Distributed under the terms of the European Union Public Licence (EUPL) V.1.1.

# fwdControl(target='data.frame', iters='array') {{{

#' fwdControl constructor for data.frame and array
#' @rdname fwdControl
setMethod('fwdControl', signature(target='data.frame', iters='array'),
  function(target, iters, ...) {
    
    # dimensions
    dtg <- dim(target)
    dit <- dim(iters)
    dni <- dimnames(iters)
    
    # COMPLETE df
    trg <- new('fwdControl')@target[rep(1, nrow(target)),]
    
    # HACK: drop rownames
    rownames(trg) <- NULL
    
    # CONVERT year to integer
    if('year' %in% names(target))
      target$year <- as.integer(target$year)
    # ASSIGN to trg, DROP 'min', 'value', 'max'
    trg[, names(target)[names(target) %in% names(trg)]] <- target

    # HACK: reassign quant to keep factors
    trg[,'quant']  <- factor(target$quant, levels=.qlevels)

    # MASTER iters
    ite <- array(NA, dim=c(dtg[1], 3, dit[length(dit)]),
      dimnames=list(row=seq(dtg[1]), val=c('min', 'value', 'max'),
      iter=seq(dit[length(dit)])))

    # MATCH arrays
    if(identical(dim(iters), dim(ite))) {
       ite[,,] <- iters
    # DIMNAMES in array?
    } else if(!is.null(dni)) {
      ite[, dni[['val']], ] <- iters
    # or NOT
    } else {
      # 2D or dim[2] == 1, assign to 'value'
      if(length(dit) == 2 | dit[2] == 1) {
        ite[,'value',] <- iters
      # 3D
      } else {
        ite[,,] <- iters
      }
    }

    # TODO CHECK quant ~ dims

    # TODO Default fcb

    # REORDER by year, season, value/min-max
    idx <- targetOrder(trg, ite)
    trg <- trg[idx,]
    row.names(trg) <- seq(len=nrow(trg))

    ite <- ite[idx,,,drop=FALSE]
    rownames(ite) <- seq(len=nrow(trg))
    
    # FIND duplicates in min/max and if found ...
    dup <- duplicated(trg)
    
    # ... MERGE max/min
    if(any(dup)){
 
      # Other HALF of duplicates     
      dup2 <- duplicated(trg, fromLast=TRUE)

      # GET duplicated iters
      ix <- ite[dup,,,drop=FALSE]
      iy <- ite[dup2,,,drop=FALSE]

      ix[,c(1,3),][is.na(ix[, c(1,3),])] <- 
        iy[,c(1,3),][!is.na(iy[, c(1,3),])]
    
      ite[dup2,,] <- ix
      ite <- ite[!dup,,,drop=FALSE] 

      trg <- trg[!dup,,drop=FALSE]

      # RE-SET rownames
      row.names(trg) <- seq(len=nrow(trg))
      rownames(ite) <- seq(len=nrow(trg))
    }

    # CHECK no duplicates
    if(any(duplicated(trg)))
      stop("target contains duplicated rows, cannot solve")

    return(new('fwdControl', target=trg, iters=ite, ...))
  }
) 
# }}}

# fwdControl(target='data.frame', iters='numeric') {{{

#' @rdname fwdControl

setMethod('fwdControl', signature(target='data.frame', iters='numeric'),
  function(target, iters, ...) {

  if(length(iters) > 1)
    stop("'iters' must be of length 1 or of class 'array'")

  # CREATE w/ empty iters
  res <- fwdControl(target=target, ...)
  # then EXTEND
  resits <- res@iters[,,rep(1, iters), drop=FALSE]
  # HACK: fix iters dimnames$iter
  dimnames(resits)$iter <- seq(1, iters)
  res@iters <- resits

  return(res)

  }
) # }}}

# fwdControl(target='data.frame', iters='missing') {{{

#' @rdname fwdControl
#' @examples
#' # Vector of values by year
#' fwdControl(data.frame(year=2010:2015, quant="f", value=seq(1, 1.3, length=6)))
#' # Two targets, with ranges for one
#' fwdControl(data.frame(year=rep(2010:2015, each=2),
#'   quant=c("f", "catch"),
#'   min=c(rbind(NA, 20000)), max=c(rbind(NA, 30000)),
#'   value=c(rbind(seq(1, 1.3, length=6), NA))))

setMethod('fwdControl', signature(target='data.frame', iters='missing'),
  function(target, ...) {
    
    # CREATE iters
    dti <- dim(target)

    ite <- array(NA, dim=c(dti[1], 3, 1), dimnames=list(row=1:dti[1], 
      val=c('min', 'value', 'max'), iter=1))

    # FIND val names in target
    vns <- c('min', 'value', 'max')
    nms <- vns %in% colnames(target)
    ite[, vns[nms], 1] <- unlist(c(target[,vns[nms]]))

    # DROP value, min, max
    target <- target[!colnames(target) %in% vns[nms]]
    
    return(fwdControl(target=target, iters=ite, ...))
  }
)
# }}}

# fwdControl(target='list', iters='missing') {{{

#' fwdControl constructor for list and missing
#' @rdname fwdControl
#' @examples
#' # Single target value
#' fwdControl(list(year=2010:2014, quant='catch', value=2900))  
#' # One value per target (year)
#' fwdControl(list(year=2010:2014, quant='catch', value=seq(2900, 3500, length=5)))  
#' # With 40 values (iters) in each target
#' fwdControl(list(year=2010:2014, quant='catch',
#'   value=rnorm(200, seq(2900, 3500, length=5))))  

setMethod('fwdControl', signature(target='list', iters='missing'),
  function(target, ...) {
    
    # target is LIST of LISTS
    if(is(target[[1]], 'list')) {
      
      inp <- lapply(target, function(x) do.call('parsefwdList', x))
      
      # target
      trg <- do.call('rbind', c(lapply(inp, '[[', 'target'), stringsAsFactors=FALSE))

      # iters
      ites <- lapply(inp, '[[', 'iters')
      
      # dims as 'row', 'val', 'iters'
      dms <- Reduce('rbind', lapply(ites, dim))

      # CHECK iters match (1/N)
      its <- max(dms[,3])
      if(any(dms[,3][dms[,3] > 1] != its))
        stop(paste("Number of iterations in 'iters' must be 1 or", its))

      # EXPAND to max iters
      ites[dms[,3] != its]  <- lapply(ites[dms[,3] != its],
        function(x) array(x, dim=c(dim(x)[-3], its)))

      # FINAL array
      # dim, sum over rows
      dms <- c(3, its, sum(dms[,1]))
      ite <- array(NA, dim=dms, dimnames=list(val=c('min', 'value', 'max'),
        iters=seq(its), row=seq(dms[3])))

      ite[] <- Reduce(c, lapply(ites, function(x) c(aperm(x, c(2,3,1)))))

      # APERM to 'row', 'val', 'iter'
      ite <- aperm(ite, c(3, 1, 2))

      return(fwdControl(target=trg, iters=ite, ...))

    } else {
      
      inp <- do.call('parsefwdList', target)
 
    return(do.call('fwdControl', c(inp, list(...))))
    }
  }
) # }}}

# fwdControl(target='list', iters='list') {{{
#' fwdControl constructor for a series of list
#' @rdname fwdControl
setMethod('fwdControl', signature(target='list', iters='list'),
  function(target, iters, ...) {
    
    args <- list(...)

    if(any(names(args) == 'FCB')) {
      nfcb <- match("FCB", names(args))
      FCB <- args[nfcb]
      args <- args[-nfcb]
    }
    else
      FCB=NULL

    # MERGE all but FCB
    target <- c(list(target, iters), args)
    
    return(do.call('fwdControl',
      c(list(target=target), FCB)))
  }
) # }}}

# fwdControl(target='missing', iters='missing') {{{
#' fwdControl constructor for mising and missing
#' @rdname fwdControl
setMethod('fwdControl', signature(target='missing', iters='missing'),
  function(...) {

    args <- list(...)

    # EMPTY
    if(length(args) == 0)
      return(new("fwdControl"))

    return(fwdControl(target=args))
  }
)

# }}}

# parsefwdList {{{

#' Parse the list argument to fwd to make a fwdControl object
#'
#' Internal function
#' @param ... Things

parsefwdList <- function(...) {
  
  args <- list(...)

  # Identify which of biol, relBiol, fishery, catch, relFishery, relCatch are lists
  fcbcols <- c("biol", "fishery", "catch", "relBiol", "relFishery", "relCatch")
  fcbcols_list <- unlist(lapply(args[fcbcols],
    function(x) return(is(x, "list") | is(x, "AsIs"))))
  listcols <- fcbcols[fcbcols_list]
  
  # Make a data.frame dropping those columns 
  dropcols <- c('value', 'min', 'max', listcols)
  df <- as.data.frame(args[!names(args) %in% dropcols], stringsAsFactors = FALSE)
  
  # if any (list | asis) are true, make a df without those cols, then add as a list
  for (i in listcols){
    df <- do.call("$<-", list(df, i, I(args[[i]])))
  }

  #  ... array components
  val <- lapply(args[names(args) %in% c('value', 'min', 'max')], c)

  # TURN val into matrix
  if(is(val, 'list')) {
    mat <- do.call(rbind, val)
  } else {
    mat <- t(matrix(val))
  }

  # NEW target
  trg <- new('fwdControl')@target[rep(1, nrow(df)),]
  trg[names(df)] <- df
  
  # COMPUTE No. iters
  dite <- max(1, ncol(mat) / nrow(trg))
  # CHECK match with length(values)
  if(dite != floor(dite))
    stop("Number of target values is not a multiple of number of targets")

  # NEW iters
  ite <- array(NA, dim=c(nrow(trg), 3, dite),
    dimnames=list(row=seq(nrow(trg)), val=c('min', 'value', 'max'),
    iter=seq(dite)))

  ite <- aperm(ite, c(2,1,3))
  ite[match(rownames(mat), dimnames(ite)$val),,] <- c(mat)
  ite <- aperm(ite, c(2,1,3))

  # RETURNS permutated array!
  return(list(target=trg, iters=ite))
} # }}}

# targetOrder {{{

#' Get the order of targets in a fwdControl
#'
#' Targets must be processed by FLasher in the correct order.
#' Internal function. Ignore.
#' @param target The target.
#' @param iters The iters.
targetOrder <- function(target, iters) {

  # ORDER by timestep and value/minmax
  tim <- suppressWarnings(as.integer(target$season))
  
  if(all(is.na(tim)))
    tim[] <- 1
  else if(sum(!is.na(tim)) != length(tim))
    stop("Season names cannot be ordered")

  idx <- order(target$year, tim)

  return(idx)
}
# }}}

# FCB {{{

#' @rdname FCB
#' @examples
#' # 1 fishery with catches from 2 biols
#' FCB(c(f=1, c=1, b=2), c(f=1, c=2, b=2))
#' # 2 fisheries with caches from 3 biols
#' FCB(c(f=1, c=1, b=1), c(f=1, c=2, b=2),
#'   c(f=2, c=1, b=2), c(f=2, c=2, b=2),
#'   c(f=2, c=3, b=3))

setMethod("FCB", signature(object="ANY"),
  function(object, ...) {

    args <- c(list(object), list(...))

    # OUTLIST list
    if(length(args) == 1 & is(args[[1]], "list"))
      args <- args[[1]]

    # USE matrix
    if(length(args) == 1 & is(args[[1]], "matrix"))
      x <- args[[1]]

  
    # CREATE matrix
    else
      x <- do.call(rbind, args)

    # CHECK dims
    if(dim(x)[2] != 3)
      stop("FCB matrix can only have 3 columns")

    dimnames(x) <- list(seq(1, dim(x)[1]), c("F", "C", "B"))

  return(x)
  }
) # }}}

# guessfcb {{{

#' Generate an FCB matrix from FLBiols and FLFisheries
#'
#' Tries to generate FCB matrix based on names.
#' Internal function. Ignore.
#' @param biols The FLBiols.
#' @param fisheries The FLFisheries.

guessfcb <- function(biols, fisheries) {

  # GET names
  nmf <- names(fisheries)
  nmc <- lapply(fisheries, names)
  nmb <- names(biols)

  fc <- do.call(rbind, lapply(names(nmc), function(x) unlist(cbind(x, nmc[[x]]))))
  b <- nmb[match(fc[,2], nmb)]

  fcb <- cbind(fc[!is.na(b),, drop=FALSE], b[!is.na(b)])
  colnames(fcb) <- c("f", "c", "b")
  rownames(fcb) <- seq(nrow(fcb))

  return(fcb)
}

# fcb2int(fcb, biols, fisheries)
#' fcb2int function
#'
#' Internal function not for public consumption
#' @param fcb The FCB matrix
#' @param biols The biols
#' @param fisheries The fisheries
fcb2int <- function(fcb, biols, fisheries) {
  
  # GET names
  nmf <- names(fisheries)
  nmc <- lapply(fisheries, names)
  nmb <- names(biols)

  fcbint <- array(NA, dim=dim(fcb), dimnames=dimnames(fcb))

  fcbint[,"f"] <- as.integer(match(fcb[,"f"], nmf))
  fcbint[,"b"] <- as.integer(match(fcb[,"b"], nmb))

  for(i in names(nmc))
    fcbint[fcb[,"f"] == i, "c"] <- match(fcb[fcb[,"f"] == i, "c"], nmc[[i]])

  return(fcbint)
} # }}}
