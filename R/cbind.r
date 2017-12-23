#'Columnwise combination of a \code{mids} object.
#'
#'Append \code{mids} objects by columns 
#'
#'This function combines two \code{mids} objects columnwise into a single
#'object of class \code{mids}, or combines a \code{mids} object with 
#'a \code{vector}, \code{matrix}, \code{factor} or \code{data.frame} 
#'columnwise into a \code{mids} object.
#'The rows in the (incomplete) data \code{x$data} and \code{y} (or
#'\code{y$data} if \code{y} is a \code{mids} object) should match. If
#'\code{y} is a \code{mids}, then \code{cbind} only works if the number 
#'of imputations in \code{x} and \code{y} is equal. 
#'
#'@param x A \code{mids} object.
#'@param y A \code{mids} object or a \code{data.frame}, \code{matrix}, 
#'\code{factor} or \code{vector}.
#'@param \dots Additional \code{data.frame}, \code{matrix}, \code{vector} or \code{factor}. 
#'These can be given as named arguments.
#'@return An S3 object of class \code{mids}
#'@note
#'The function construct the elements of the new \code{mids} object as follows:
#'\tabular{ll}{
#'\code{data}     \tab Columnwise combination of the (incomplete) data in \code{x} and \code{y}\cr
#'\code{imp}      \tab Appends \code{x$imp} and \code{y$imp} if \code{y} is \code{mids} object\cr
#'\code{m}        \tab Equals \code{x$m}\cr
#'\code{where}    \tab Columnwise combination of \code{where} arguments\cr
#'\code{blocks}   \tab Appends \code{x$blocks} and \code{y$blocks}\cr
#'\code{call}     \tab Vector, \code{call[1]} creates \code{x}, \code{call[2]} is call to \code{cbind.mids}\cr
#'\code{nmis}     \tab Equals c(x$nmis, y$nmis)\cr
#'\code{method}   \tab Combines \code{x$method} and \code{y$method}\cr
#'\code{predictorMatrix} \tab Combines \code{x$predictorMatrix} and \code{y$predictMatrix} with zero matrices on the off-diagonal blocks\cr
#'\code{visitSequence}   \tab Taken from \code{x$visitSequence}\cr
#'\code{formulas}  \tab Taken from \code{x$formulas}\cr
#'\code{post}      \tab Taken from \code{x$post}\cr
#'\code{blots}     \tab Taken from \code{x$blots}\cr
#'\code{seed}            \tab Taken from \code{x$seed}\cr
#'\code{iteration}       \tab Taken from \code{x$iteration}\cr
#'\code{lastSeedValue}   \tab Taken from \code{x$lastSeedValue}\cr
#'\code{chainMean}       \tab Combines \code{x$chainMean} and \code{y$chainMean}\cr
#'\code{chainVar}        \tab Combines \code{x$chainVar} and \code{y$chainVar}\cr
#'\code{loggedEvents}    \tab Taken from \code{x$loggedEvents}\cr
#'\code{version}    \tab Taken from \code{x$version}\cr
#'\code{date}       \tab Taken from \code{x$date}
#'}
#'
#'@author Karin Groothuis-Oudshoorn, Stef van Buuren
#'@seealso \code{\link{rbind.mids}}, \code{\link{ibind}}, \code{\link[=mids-class]{mids}}
#'@keywords manip
#'@examples
#'
#'# impute four variables at once (default)
#'imp <- mice(nhanes, m = 1, maxit = 1, print = FALSE)
#'imp$predictorMatrix
#'
#'# impute two by two
#'data1 <- nhanes[, c("age", "bmi")]
#'data2 <- nhanes[, c("hyp", "chl")]
#'imp1 <- mice(data1, m = 2, maxit = 1, print = FALSE)
#'imp2 <- mice(data2, m = 2, maxit = 1, print = FALSE)
#'
#'# Append two solutions
#'imp12 <- cbind(imp1, imp2)
#'
#'# This is a different imputation model
#'imp12$predictorMatrix
#'
#'# Append the other way around
#'imp21 <- cbind(imp2, imp1)
#'imp21$predictorMatrix
#'
#'# Append 'forgotten' variable chl
#'data3 <- nhanes[, 1:3]
#'imp3  <- mice(data3, maxit = 1,m = 2, print = FALSE)
#'imp3a <- cbind(imp3, chl = nhanes$chl)
#'
#'# Of course, chl was not imputed
#'head(complete(imp3a))
#'
#'# Note: If one of the arguments is a data.frame 
#'# we need to explicitly call mice:::cbind.mids()
#'imp3b <- mice:::cbind.mids(imp3, data.frame(chl = nhanes$chl))
#'@export
cbind.mids <- function(x, y = NULL, ...) {
  call <- match.call()
  if (!is.mids(y)) {
    # Combine y and dots into data.frame
    if (is.null(y)) {
      y <- cbind.data.frame(...) 
    } else {
      y <- cbind.data.frame(y, ...)
    }
    if (is.matrix(y) || is.vector(y) || is.factor(y))
      y <- as.data.frame(y)
    
    # Replicate rows of y
    if (nrow(y) == 1) {
      y <- y[rep(row.names(y), nrow(x$data)), seq_along(y)]
      row.names(y) <- row.names(x$data)
    }
    
    if (nrow(y) != nrow(x$data)) 
      stop("Datasets have different number of rows")
    
    varnames <- c(colnames(x$data), colnames(y))
    
    # Call is a vector, with first argument the mice statement and second argument the call to cbind.mids.
    call <- c(x$call, call)
    
    # The data in x (x$data) and y are combined together.
    data <- cbind(x$data, y)
    
    # where argument
    where <- cbind(x$where, matrix(FALSE, nrow = nrow(y), ncol = ncol(y)))
    colnames(where) <- varnames
    blocks <- c(x$blocks, colnames(y))
    blocks <- name.blocks(blocks)
    
    # The number of imputations in the new midsobject is equal to that in x.
    m <- x$m
    
    # count the number of missing data in y
    nmis <- c(x$nmis, colSums(is.na(y)))
    
    # The original data of y will be copied into the multiple imputed dataset, 
    # including the missing values of y.
    r <- (!is.na(y))
    
    f <- function(j) {
      m <- matrix(NA,
                  nrow = sum(!r[, j]),
                  ncol = x$m,
                  dimnames = list(row.names(y)[!r[, j]], seq_len(m)))
      as.data.frame(m)
    }
    
    imp <- lapply(seq_len(ncol(y)), f)
    imp <- c(x$imp, imp)
    names(imp) <- varnames
    
    # The imputation method for (columns in) y will be set to ''.
    method <- c(x$method, rep.int("", ncol(y)))
    names(method) <- c(names(x$method), colnames(y))
    
    # The variable(s) in y are included in the predictorMatrix.  y is not used as predictor as well as not imputed.
    predictorMatrix <- rbind(x$predictorMatrix, matrix(0, ncol = ncol(x$predictorMatrix), nrow = ncol(y)))
    predictorMatrix <- cbind(predictorMatrix, matrix(0, ncol = ncol(y), nrow = nrow(x$predictorMatrix) + ncol(y)))
    dimnames(predictorMatrix) <- list(names(blocks), varnames)
    
    # The visitSequence is taken as in x$visitSequence.
    visitSequence <- x$visitSequence
    
    # The post vector for (columns in) y will be set to ''.
    post <- c(x$post, rep.int("", ncol(y)))
    names(post) <- c(names(x$post), colnames(y))

    # No new formula list will be created
    formulas <- x$formulas
    blots <- x$blots

    # seed, lastSeedvalue, number of iterations, chainMean and chainVar is taken as in mids object x.
    seed <- x$seed
    lastSeedvalue <- x$lastSeedvalue
    iteration <- x$iteration
    chainMean = x$chainMean
    chainVar = x$chainVar
    
    loggedEvents <- x$loggedEvents
    
    ## save, and return
    midsobj <- list(data = data, imp = imp, m = m,
                    where = where, blocks = blocks, 
                    call = call, nmis = nmis, 
                    method = method,
                    predictorMatrix = predictorMatrix,
                    visitSequence = visitSequence, 
                    formulas = formulas, post = post, seed = seed, 
                    iteration = iteration,
                    lastSeedValue = .Random.seed, 
                    chainMean = chainMean,
                    chainVar = chainVar, 
                    loggedEvents = loggedEvents, 
                    version = packageVersion("mice"),
                    date = Sys.Date())
    oldClass(midsobj) <- "mids"
    return(midsobj)
  }
  
  if (is.mids(y)) {
    
    if (nrow(y$data) != nrow(x$data)) 
      stop("The two datasets do not have the same length\n")
    if (x$m != y$m) 
      stop("The two mids objects should have the same number of imputations\n")
    
    # Call is a vector, with first argument the mice statement and second argument the call to cbind.mids.
    call <- c(x$call, call)
    
    # The data in x$data and y$data are combined together.
    data <- cbind(x$data, y$data)
    varnames <- c(colnames(x$data), colnames(y$data))
    
    where <- cbind(x$where, y$where)
    blocks <- c(x$blocks, y$blocks)
    
    m <- x$m
    nmis <- c(x$nmis, y$nmis)
    imp <- c(x$imp, y$imp)
    method <- c(x$method, y$method)
    
    # The predictorMatrices of x and y are combined with zero matrices on the off diagonal blocks.
    predictorMatrix <- rbind(x$predictorMatrix, 
                             matrix(0, ncol = ncol(x$predictorMatrix), nrow = nrow(y$predictorMatrix)))
    predictorMatrix <- cbind(predictorMatrix, 
                             rbind(matrix(0, 
                                          ncol = ncol(y$predictorMatrix), 
                                          nrow = nrow(x$predictorMatrix)), 
                                   y$predictorMatrix))
    dimnames(predictorMatrix) <- list(varnames, varnames)
    
    # As visitSequence is taken first the order for x and after that from y.
    visitSequence <- c(x$visitSequence, y$visitSequence)
    
    formulas <- c(x$formulas, y$formulas)
    post <- c(x$post, y$post)
    blots <- c(x$blots, y$blots)
    
    # For the elements seed, lastSeedvalue and iteration the values from midsobject x are copied.
    seed <- x$seed
    lastSeedvalue <- x$lastSeedvalue
    iteration <- x$iteration
    
    # the chainMean and chainVar vectors for x and y are combined.
    chainMean <- array(data = NA, 
                       dim = c(dim(x$chainMean)[1] + dim(y$chainMean)[1], iteration, m), 
                       dimnames = list(c(dimnames(x$chainMean)[[1]], 
                                         dimnames(y$chainMean)[[1]]), 
                                       dimnames(x$chainMean)[[2]], 
                                       dimnames(x$chainMean)[[3]]))
    chainMean[seq_len(dim(x$chainMean)[1]), , ] <- x$chainMean
    
    if (iteration <= dim(y$chainMean)[2]) {
      chainMean[(dim(x$chainMean)[1] + 1):dim(chainMean)[1], , ] <- y$chainMean[, seq_len(iteration), ] 
    } else { 
      chainMean[(dim(x$chainMean)[1] + 1):dim(chainMean)[1], seq_len(dim(y$chainMean)[2]), ] <- y$chainMean
    }
    
    chainVar <- array(data = NA, dim = c(dim(x$chainVar)[1] + dim(y$chainVar)[1], iteration, m), 
                      dimnames = list(c(dimnames(x$chainVar)[[1]], 
                                        dimnames(y$chainVar)[[1]]), 
                                      dimnames(x$chainVar)[[2]], 
                                      dimnames(x$chainVar)[[3]]))
    chainVar[seq_len(dim(x$chainVar)[1]), , ] <- x$chainVar
    
    if (iteration <= dim(y$chainVar)[2]) {
      chainVar[(dim(x$chainVar)[1] + 1):dim(chainVar)[1], , ] <- y$chainVar[, seq_len(iteration), ] 
    } else { 
      chainVar[(dim(x$chainVar)[1] + 1):dim(chainVar)[1], seq_len(dim(y$chainVar)[2]), ] <- y$chainVar
    }
    
    loggedEvents <- x$loggedEvents
    
    midsobj <- list(data = data, imp = imp, m = m,
                    where = where, blocks = blocks, 
                    call = call, nmis = nmis, 
                    method = method,
                    predictorMatrix = predictorMatrix,
                    visitSequence = visitSequence, 
                    formulas = formulas, post = post, 
                    blots = blots, seed = seed, 
                    iteration = iteration,
                    lastSeedValue = .Random.seed, 
                    chainMean = chainMean,
                    chainVar = chainVar, 
                    loggedEvents = loggedEvents, 
                    version = packageVersion("mice"),
                    date = Sys.Date())
    oldClass(midsobj) <- "mids"
    return(midsobj)
  }
}
