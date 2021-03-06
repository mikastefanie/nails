
###############################################################################

# Do topic modeling on abstracts using the lda libraries
# Do not use alone (loaded from the cleaning2.R)

# Libraries
library(tm)
library(SnowballC)
library(lda)
library(LDAvis)
# Enable multicore processing (works only on *NIX-based systems)
#library(doMC)
#registerDoMC(4)

# Import data (see cleaning2.R)
data <- literature$Abstract

# read in English stopwords from the SMART collection
stop_words <- stopwords("SMART")

# pre-processing (remove stopwords; destem)
data <- gsub("'", "", data)  # remove apostrophes
data <- gsub("[[:punct:]]", " ", data)  # replace punctuation with space
data <- gsub("[[:cntrl:]]", " ", data)  # replace control characters with space
data <- gsub("^[[:space:]]+", "", data) # remove whitespace at beginning of documents
data <- gsub("[[:space:]]+$", "", data) # remove whitespace at end of documents
data <- tolower(data)  # force to lowercase
data <- stemDocument(data)

# tokenize on space and output as a list
doc.list <- strsplit(data, "[[:space:]]+")

# compute the table of terms
term.table <- table(unlist(doc.list))
term.table <- sort(term.table, decreasing = TRUE)

# remove terms that are stop words or occur fewer than 5 times
del <- names(term.table) %in% stop_words | term.table < 5
term.table <- term.table[!del]
vocab <- names(term.table)

# now put the documents into the format required by the lda package
get.terms <- function(x) {
  index <- match(x, vocab)
  index <- index[!is.na(index)]
  rbind(as.integer(index - 1), as.integer(rep(1, length(index))))
}
# mclapply is the multicore enabled version of lapply
documents <- lapply(doc.list, get.terms)

# Compute some statistics related to the data set:
D <- length(documents)  # number of documents (2,000)
W <- length(vocab)  # number of terms in the vocab (14,568)
doc.length <- sapply(documents, function(x) sum(x[2, ]))  # number of tokens per document [312, 288, 170, 436, 291, ...]
N <- sum(doc.length)  # total number of tokens in the data (546,827)
term.frequency <- as.integer(term.table)  # frequencies of terms in the corpus [8939, 5544, 2411, 2410, 2143, ...]

# MCMC and model tuning parameters
K <- 6 # number of topics
G <- 2500 # iterations
alpha <- 0.166 # 1 / K
eta <- 0.166 # 1 / K

# Fit the model
set.seed(357)

fit <- lda.collapsed.gibbs.sampler(documents = documents, K = K, vocab = vocab,
                                   num.iterations = G, alpha = alpha,
                                   eta = eta, initial = NULL, burnin = 0,
                                   compute.log.likelihood = TRUE)

# Document topic matrix (transposed to get topic probabilities for each document)
topicsfordocs <- t(fit$document_sums)
# Convert to data frame
tfdDF <- data.frame(topicsfordocs)
# Add top topics document
tfdDF$toptopic <- colnames(tfdDF)[max.col(tfdDF,ties.method="first")]

# Summary statistics
# Most likely documents for each topic
topdocsfortopic <- top.topic.documents(fit$document_sums)
# Ten most likely words for each topic
topwords <- top.topic.words(fit$topics, 10, by.score = TRUE)

theta <- t(apply(fit$document_sums + alpha, 2, function(x) x/sum(x)))
phi <- t(apply(t(fit$topics) + eta, 2, function(x) x/sum(x)))

TopicModel    <- list(phi = phi,
                      theta = theta,
                      doc.length = doc.length,
                      vocab = vocab,
                      term.frequency = term.frequency)


# create the JSON object to feed the visualization
json <- createJSON(phi = TopicModel$phi,
                   theta = TopicModel$theta,
                   doc.length = TopicModel$doc.length,
                   vocab = TopicModel$vocab,
                   term.frequency = TopicModel$term.frequency)

# Freeing up memory
rm(data)
rm(documents)
rm(vocab)
rm(TopicModel)
rm(fit)

