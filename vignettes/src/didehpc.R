## ---
## title: "R and the DIDE cluster"
## author: "Rich FitzJohn"
## date: "`r Sys.Date()`"
## output:
##   rmarkdown::html_vignette:
##     toc: true
##     toc_depth: 2
## vignette: >
##   %\VignetteIndexEntry{R and the DIDE cluster}
##   %\VignetteEngine{knitr::rmarkdown}
##   %\VignetteEncoding{UTF-8}
## ---

### If knitr fails, you'll get an error
###
### Error in file(file, ifelse(append, "a", "w")) :
###   cannot open the connection
### Calls: <Anonymous> ... handle -> withCallingHandlers -> withVisible -> eval -> eval
### In addition: Warning message:
### In file(file, ifelse(append, "a", "w")) :
###   cannot open file 'quickstart.md': Permission denied
###
### With no information as to where the chunk that fails is.  Running
### in interactive mode can help.  Have fun debugging!
##+ echo = FALSE,results = "hide"
source("common.R")

## Parallel computing on a cluster can be more challenging than
## running things locally because it's often the first time that you
## need to package up code to run elsewhere, and when things go wrong
## it's more difficult to get information on why things failed.

## Much of the difficulty of getting things running involves working
## out what your code depends on, and getting that installed in the
## right place on a computer that you can't physically poke at.  The
## next set of problems is dealing with the balloning set of files
## that end up being created - templates, scripts, output files, etc.

## This set of packages
## ([`didehpc`](https://github.com/mrc-ide/didehpc),
## [`queuer`](https://github.com/mrc-ide/queuer) and
## [`context`](https://github.com/mrc-ide/context), along with a
## couple of support packages
## ([`provisionr`](https://github.com/mrc-ide/provisionr),
## [`buildr`](https://github.com/mrc-ide/buildr),
## [`syncr`](https://github.com/mrc-ide/syncr),
## [`rrq`](https://github.com/mrc-ide/rrq) and
## [`storr`](https://github.com/richfitz/storr)) aims to remove the
## pain of getting everything set up, and getting cluster tasks
## running, and retrieving your results.

## Once everything is set up, running a job on the cluster should be
## as straightforward as running things locally.

## The documentation here runs through a few of the key concepts, then
## walks through setting this all up.  There's also a "quick start"
## guide that contains much less discussion.

## ## Functions

## The biggest conceptual move is from thinking about running
## **scripts** that generate *files* to running **functions** that
## return *objects*.  The reason for this is that gives a well defined
## interface to build everything else around.
##
## The problem with scripts is that they might do almost anything.
## They depend on untold files and packages which they load wherever.
## The produce any number of objects.  That's fine, but it becomes
## hard to reason about them to plan deploying them elsewhere, to
## capture the outputs appropriately, or to orchestrate looping over a
## bunch of paramter values.  If you've found yourself writing a
## number of script files changing values with text substitution you
## have run into this.
##
## In contrast, functions do (ideally) one thing.  They have a well
## defined set of inputs (their arguments) and outputs (their return
## value).  We can loop over a range of input values by iterating over
## a set of arguments.
##
## This set of packages tends to work best if you let it look after
## filenames.  Rather than trying to come up with a naming scheme for
## different files as based on parameter values, just return objects
## and the packages will arrange for them to be saved and reloaded.

## ## Filesystems

## The DIDE cluster needs everything to be available on a filesystem
## that the cluster can read.  Practically this means the filesystems
## `//fi--didef2/tmp` or `//fi--san03/homes/username` and the like.
## You probably have access to network shares that are specific to a
## project, too.  For Windows users these are probably mapped to
## drives (`Q:` or `T:` or similar) already, but for other platforms
## you will need to do a little extra work to get things set up (see
## below).

## It is simplest if *everything* that is needed for a project is
## present in a single directory that is visible on the cluster.
## However, other patterns are possible; see "Running out of place"
## towards the bottom of this page.

## However for the most of this document I will assume that everything
## is in one directory, which is on a network share.

## # Getting started

## The initial setup will feel like a headache at first, but it should
## ultimately take only a few lines.  Once everything is set up, then
## the payback is that is the job submission part will become a lot
## simpler.

## ## Installation

## Install the packages using [`drat`](https://cran.rstudio.com/package=drat)
##
## ```r
## # install.package("drat") # if you don't have it already
## drat:::add("mrc-ide")
## install.packages("didehpc")
## ```

## Or, somewhat equivalently
##
## ```r
## source("https://mrc-ide.github.io/didehpc/install")
## ```

## Be sure to run this in a fresh session.

## ## Configuration

## The configuration is handled in a two stage process.  First, some
## bits that are machine specific are set using `options` with option
## names that are prefixed with `didehpc`.  Then when a queue is
## created, further values can be passed along via the `config`
## argument that will use the "global" options as a default.

## The reason for this separation is that ideally the machine-specific
## options will not end up in scripts, because that makes things less
## portable (for example, we need to get your username, but your
## username is unlikely to work for your collaborators).

## Ideally in your ~/.Rprofile file, you will add something like:
##
## ```r
## options(
##   didehpc.username = "rfitzjoh",
##   didehpc.home = "~/net/home")
## ```
##
## and then set only options (such as cluster and cores or template)
## that vary with a project.

## If you use the "big" cluster, you can add `didehpc.cluster =
## "fi--didemrchnb"` here.

## At the moment (while things change) it might be simplest to set
## things using the `didehpc::didehpc_config_global` function.  The
## help file `?didehpc::didehpc_config` outlines the options here.  At
## the moment a minimal set of options is your credentials (not needed
## on Windows domain machines) and the cluster you wish to use (if you
## don't want to use the small cluster).

## There are lots of configuration options that can be tweaked, but I
## suggest setting things this way *only* for things that will hold
## for all projects.

## ### Credentials

## Windows users will not need to provide anything unless they are on
## a non-domain machine or they are in the unfortunate situation of
## juggling multiple usernames across systems.  Non-domain machines
## will need the credentials set as above.

## Mac users will need to provide their username here as above.

## If you have a Linux system and have configured your smb mounts as
## described below, you might as well take advantage of this and set
## `credentials = "~/.smbcredentials"` and you will never be prompted
## for your password:
##
## ```r
## options(didehpc.credentials = "~/.smbcredentials")
## ```

## ### Seeing the default configuration

## To see the configuration that will be run if you don't do anything
## (else), run:
didehpc::didehpc_config()

## In here you can see the cluster (here, `fi--didemrchnb`),
## credentials and username, the job template (`GeneralNodes`),
## information about the resources that will be requested (1 core) and
## information on filesystem mappings.  There are a few other bits of
## information that may be explained further down.  The possible
## options are explained further in `?didehpc::didehpc_config`

## ### Additional shares

## If you refer to network shares in your functions, e.g., to refer to
## data, you'll need to map these too.  To do that, pass them as the
## `shares` argument to `didehpc_config_global`.

## To describe each share, use the `didehpc::path_mapping` function
## which takes arguments:
##
## * name: a desctiptive name for the share
## * `path_local`: the point where the share is mounted on your computer
## * `path_remote`: the network path that the share refers to (forward
##   slashes are much easier to enter here than backward slashes)
## * `drive_remote`: the drive this should be mapped to on the cluster.

## So to map your "M drive" to which points at `\\fi--didef2\malaria`
## to `M:` on the cluster you can write
##
## ```r
## share <- didehpc::path_mapping("malaria", "M:", "//fi--didef2/malaria", "M:")
## config <- didehpc::didehpc_config(shares = share)
## ```

## If you have more than one share to map, pass them through as a list
## (e.g., `didehpc::didehpc_config(shares = list(share1, share2, ...))`).

## For most systems we `didehpc` will do a reasonable job of detecting
## the shares that you are running on, so this should (hopefully) only
## be necessary for detecting additional shares.  The issue there is
## that you'll need to use absolute paths to refer to the resources
## and that's going to complicate things...

## ## Contexts

## To recreate your work environment on the cluster, we use a package
## called `context`.  This package uses the assumption that most
## working environments can be recreated by a combination of R
## packages and sourcing a set of function definitions.

## In order to have the system tell you more about what it is doing,
## you can (optionally) run this command.  This can be a bit more
## reassuring during long-running setup stages
context::context_log_start()

## ### Root

## Every context has a "root"; this is the directory that everything
## will be saved in.  Most of the examples in the help use `contexts`
## which is fairly self explanatory but it can be any directory.
## Generally it will be in the current directory.
root <- "contexts"

## This directory is going to get large over time and will eventually
## need to be deleted.  Eventually I will come up with some tools to
## simplify working with these.  In the meantime, treat these as
## somewhat disposable.

## ### Packages

## If you list packages as a character vector then all packages will
## be installed for you, and they will also be *attached*; this is
## what happens when you use the function `library()` So for example
## if you need to depend on the `rstan` and `ape` packages you could
## write:
##
## ```r
## ctx <- context::context_save(root, packages = c("rstan", "ape"))
## ```

## Attaching packages is not always what is wanted, especially if you
## have packages that clobber functions in base packages (e.g.,
## `dplyr`!).  An alternative is to list a set of packages that you
## want installed and split them into packages you would like attached
## and packages you would only like loaded:
##
## ```r
## packages <- list(loaded = "geiger", attached = "ape")
## ctx <- context::context_save(root, packages = packages)
## ```
##
## In this case, the packages in the `loaded` section will be
## installed (along with their dependencies) and before anything runs,
## we will run `loadNamespace` on them to confirm that they are
## properly available.  Access functions in this package with the
## double-colon operator, like `geiger::fitContinuous`.  However they
## will not be attached so will not modify the search path.

## In contrast, packages listed in `attached` will be loaded with
## `library` so they will be available without qualification (e.g.,
## `read.tree` rather than `ape::read.tree`).

## ### Source files for function definitions

## If you define any of your own functions you will need to tell the
## cluster about them.  The easiest way to do this is to save them in
## a file that contains only function definitions (and does not read
## data, etc).

## For example, I have a file `mysources.R` with a very simple tree
## simulation in it.  Imagine this is some slow function that given an
## integer `nspp` after a bunch of calculation yields a tree with
## `nspp` tips:

##+ echo = FALSE, results = "asis"
writeLines(c("```r", readLines("mysources.R"), "```"))

## To set this up, we'd write:
ctx <- context::context_save(root, packages = "ape", sources = "mysources.R")

## `sources` can be a character vector, `NULL` or `character(0)` if
## you have no sources, or just omit it as above.

## ### Custom packages

## If you depend on packages that are not on CRAN (e.g., your personal
## research code) you'll need to tell `context` where to find them
## with its `package_sources` argument.

## If the packages are on GitHub and public you can pass the github
## username/repo pair, in `devtools` style:

## ```r
## context::context_save(...,
##   package_sources = provisionr::package_sources(github = "richfitz/kitten"))
## ```

## Like with `devtools` you can use subdirectories, specific commits
## or tags in the specification.

## If the packages are private, it is simplest to pass the path to
## where the package can be found on your computer with the `local`
## argument to `package_sources`.

## ## Creating the queue

## Once a context has been created, we can create a queue with it.
## This is separate from the actual cluster queue, but will be our
## interface to it.  Running this step takes a while because it
## installs all the packages that the cluster will need into the
## context directory.
obj <- didehpc::queue_didehpc(ctx)

## If the above command does not throw an error, then you have
## successfully logged in.  When you run `queue_didehpc` it will
## install windows versions of all required packages within the `root`
## directory (here, "contexts").  This is necessary even when you are
## on windows because the cluster cannot see files that are on your
## computer.

## `obj` is a weird sort of object called an `R6` class.  It's a bit
## like a Python or Java class if you've come from those languages.
## The thing you need to know is that the object is like a list and
## contains a number of functions that can be run by runing
## `obj$functionname()`.  These functions all act by *side effect*;
## they interact with a little database stored in the context root
## directory or by communicating with the cluster using the web
## interface that Wes created.
obj

## For example, to list the tasks that we know about:
obj$task_list()

## (of course there are no tasks yet because we haven't added any).
## As a slightly more interesting example we can see how busy the
## cluster is:
obj$cluster_load()

## (if you're on a ANSI-compatible terminal this will be in glorious
## colour).

## ## Testing that the queue works correctly

## Before running a real job, let's test that everything works
## correctly by running the `sessionInfo` command on the cluster.
## When run locally, `sessionInfo` prints information about the state
## of your R session:
sessionInfo()

## To run this on the cluster, we wrap it in `obj$enqueue`.  This
## prevents the evaluation of the expression and instead organises it
## to be run on the cluster:
t <- obj$enqueue(sessionInfo())

## We can then poll the cluster for results until it completes:
t$wait(100)

## (see the next section for more information about this).

## The important part to notice here is that the R "Platform" (second
## and third line) is Windows Server, as opposed to the host machine
## which is running Linux.  In addition note that `ape` is lited under
## "other attached packages" and that `context`, as well as some other
## packages (`R6` `storr` and `digest` in particular) have been
## installed and are loaded (but not attached).  This shows that the
## system has set up a working environment like our local one on the
## remote machine, and we can evaluate tasks in it!

## ## Running single jobs

## Let's run something more interesting now by running the `make_tree`
## function defined in the `mysources.R` file.

## As above, jobs are queueed by running:
t <- obj$enqueue(make_tree(10))

## Like the queue object, `obj`, task objects are R6 objects that can
## be used to get information and results back from the task.
t

## the task's status
t$status()

## ...which will move from `PENDING` to `RUNNING` to `COMPLETE` or
## `ERROR`.  You can get information on submission and running times
t$times()

## and you can try and get the result of running the task:
##+ error = TRUE
t$result()

## The `wait` function, used above, is like `result` but it will
## repeatedly poll for the task to be completed for up to `timeout`
## seconds.
t$wait(100)

## once the task has completed, `t$result()` and `t$wait` are equivalent
t$result()

## Every task creates a log:
t$log()

## Warning messages and other output will be printed here.  So if you
## include `message()`, `cat()` or `print()` calls in your task they
## will appear between `start` and `end`.

## There is another bit of log that happens before this and contains
## information about getting the system started up.  You should only
## need to look at this when a job seems to get stuck with status
## `PENDING` for ages.
obj$dide_log(t)

## The queue knows which tasks it has created and you can list them:
obj$task_list()

## The long identifiers are random and are long enough that collisions
## are unlikely.

## Notice that the task ran remotely but we never had to indicate
## which filename things were written to.  There is a small database
## based on [`storr`](https://richfitz.github.com/storr) that holds
## all the information within the context root (here, "contexts").
## This means you can close down R and later on regenerate the `ctx`
## and `obj` objects and recreate the task objects, and re-get your
## results.  But at the same time it provides the _illusion_ that the
## cluster has passed an object directly back to you.
id <- t$id
id

t2 <- obj$task_get(id)
t2$result()

## ## Running many jobs

## There are two broad options here;

## 1. Apply a function to each element of a list, similar to `lapply`
## with `$lapply`
## 2. Apply a function to each row of a data.frame perhaps using each
## column as a different argument with `$enqueue_bulk`

## The second approach is more general and `$lapply` is implemented
## using it.

## Suppose we want to make a bunch of trees of different sizes.  This
## would involve mapping our `make_tree` function over a vector of
## sizes:
sizes <- 3:8
grp <- obj$lapply(sizes, make_tree)

## By default, `$qlapply` returns a "task_bundle" with an
## automatically generated name.  You can customise the name with the
## `name` argument.

## In contrast to `lapply` this is not blocking (i.e., submitting
## tasks and collecting the results is done asynchronously) but if you
## pass a `timeout` argument to `$lapply` then it will poll until the
## jobs are done, in the same way as `wait()`, below.

## Get the startus of all the jobs
grp$status()

## Wait until they are all complete and get the results
res <- grp$wait(120)

## The other bulk interface is where you want to run a function over a
## combination of parameters.  Use `queuer::enqueue_bulk` here.
pars <- expand.grid(a = letters[1:3], b = runif(2), c = pi,
                    stringsAsFactors = FALSE)
pars

## Suppose that we have a function that we want to run over this set
## of parameters.
combine(pars$a[[1]], pars$b[[1]], pars$c[[1]])

grp <- obj$enqueue_bulk(pars, combine, do_call = TRUE)

## By default this runs
##
## * `combine(a = pars$a[[1]], b = pars$b[[1]], c = pars$c[[1]])`
## * `combine(a = pars$a[[2]], b = pars$b[[2]], c = pars$c[[2]])`
## * ...
## * `combine(a = pars$a[[6]], b = pars$b[[6]], c = pars$c[[6]])`

res <- grp$wait(120)
res

## Running `do_call = FALSE` would run functions as a row-wise `lapply`.

## ## Cancelling and stopping jobs

## Suppose you fire off a bunch of jobs and realise that you have the
## wrong data or they're all going to fail - you can stop them fairly
## easily.

## Here's a job that will run for an hour and return nothing:
t <- obj$enqueue(Sys.sleep(3600))

## Wait for the job to start up:
while (t$status() == "PENDING") {
  Sys.sleep(.5)
}

## Now that it's started it can be cancelled with the `$unsubmit` method:
obj$unsubmit(t$id)

## unsubmitting multiple times is safe, and will have no effect.
obj$unsubmit(t$id)

## Alternatively you can use `obj$task_delete(t$id)` which unsubmits
## the task and then deletes it.

## Note that the task is not actually deleted (see below); you can
## still get at the expression:
t$expr()

## but you cannot retrieve results:
##+ error = TRUE
t$result()

## The argument to `unsubmit` can be a vector.  For example, to
## unsubmit a whole task bundle:
grp <- queuer::qlapply(rep(3600, 4), Sys.sleep, obj)
obj$unsubmit(grp$ids)

## ### Deleting jobs

## Deleting tasks is supported but it isn't entirely encouraged.  Not
## all of the functions behave well with missing tasks, so if you
## delete things and still have old task handles floating around you
## might get confusing results.

## There is a delete method (`obj$delete`) that will delete jobs,
## first unsubmitting it if it has been submitted.  It takes a vector
## of task ids as an argument.

## # Misc

## ## Jobs that require compiled code

## If you are running stan, or Rcpp with `sourceCpp` (in the latter
## case you *should* be using a package) you'll need a working
## compiler.  For rstan this is detected automatically.  But in
## general, pass `rtools = TRUE` to `queue_didehpc()`.

## ## Parallel computation on the cluster

## If you are running tasks that can use more than one core, you can
## request more resources for your task and use process level
## parallism with the `parallel` package.  To request 8 cores, you
## could run:

## ```r
## didehpc::didehpc_config(cores = 8)
## ```

## When your task starts, 8 cores will be allocated to it and a
## `parallel` cluster will be created.  You can use it with things
## like `parallel::parLapply`, specifying `cl` as `NULL`.  So if
## within your cluster job you needed to apply function `f` to a each
## element of a list `x`, you could write:

## ```r
## run_f <- function(x) {
##   parallel::parLapply(NULL, x, f)
## }
## obj$enqueue(run_f(x))
## ```

## The parallel bits can be embedded within larger blocks of code.
## All functions in `parallel` that take `cl` as a first argument can
## be used.  You do not need to (and should not) set up the cluster as
## this will happen automatically as the job starts.

## Alternatively, if you want to control cluster creation (e.g., you
## are using software that does this for you) then, pass
## `parallel = FALSE` to the config call:

## ```r
## didehpc::didehpc_config(cores = 8, parallel = FALSE)
## ```

## In this case you are responsible for setting up the cluster.

## As an alternative to requesting cores, you can use a different job
## template:
##
## ```r
## didehpc::didehpc_config(template = "16Core")
## ```

## which will reserve you the entire node.  Again, a cluster will be
## started with all availabe cores unless you also specify
## `parallel = FALSE`.

## ## Running heaps of jobs without annoying your colleagues

## If you have thousands and thousands of jobs to submit at once you
## may not want to flood the cluster with them all at once.  Each job
## submission is relatively slow (the HPC tools that the web interface
## has to use are relatively slow).  The actual queue that the cluster
## uses doesn't seem to like processing tens of thousands of job, and
## can slow down.  And if you take up the whole cluster someone may
## come and knock on your office and complain at you.  At the same
## time, batching your jobs up into little bits and manually sending
## them off is a pain and work better done by a computer.

## An alternative is to submit a set of "workers" to the cluster, and
## then submit jobs to them.  This is done with the
## [`rrq`](https://github.com/mrc-ide/rrq) package, along with a
## [`redis`](http://redis.io) server running on the cluster.

## See the "workers" vignette for details.

## ## `rstan`

## To use parallel chains, do something like:

## ```r
## config <- didehpc::didehpc_config(cores = 4, parallel = FALSE)
## obj <- didehpc::queue_didehpc(ctx, config)
## ```

## to request four cores or

## ```r
## config <- didehpc::didehpc_config(wholenode = TRUE, parallel = FALSE)
## obj <- didehpc::queue_didehpc(ctx, config)
## ```

## to request a whole node.  The `parallel = FALSE` tells the system not
## to set up a cluster for use with the `parallel` pacakge.  However,
## you'll still need to specify options(mc.cores) appropriately and I
## don't expose that yet...

## ## Using Microsoft HPC tools

## This section is only relevant for Windows users who are used to
## using the Windows Job Manager software in Microsoft HPC Pack.

## If you have used the cluster tools from windows before, then you
## may be used to seeing your name show up in the HPC job manager.  By
## default if you submit jobs with this tool, you will not see that as
## they're actually submitted by a process on the cluster but run *as*
## you.  See the [cluster
## wiki](https://mrcdata.dide.ic.ac.uk/wiki/index.php/HPC_Web_Portal#Notes_for_Windows_Job_Manager_Users)
## for more information.

## If you want this behaviour back, `didehpc` can be configured to use
## the HPC tools on your computer.  Just run:

## ```r
## didehpc::didehpc_config_global(hpctools = TRUE)
## ```

## or

## ```r
## options(didehpc.hpctools = TRUE)
## ```

## before creating the queue, or run

## ```r
## obj <- didehpc::queue(ctx, config = didehpc::didehpc_config(hpctools = TRUE))
## ```

## This is experimental but I welcome feedback.

## # Mapping network drives

## For all operating systems, if you are on the wireless network you
## will need to connect to the VPN.  If you can get on a wired network
## you'll likely have a better time because the VPN and wireless
## network seems less stable in general.  Instructions for setting up
## a VPN are
## [here](https://www1.imperial.ac.uk/publichealth/departments/ide/it/remote)

## ## Windows

## Your network drives are likely already mapped for you.  In fact you
## should not even need to map drives as fully qualified network names
## (e.g. `//fi--didef2/tmp`) should work for you.

## ## Mac OS/X

## In Finder, go to `Go -> Connect to Server...` or press `Command-K`.
## In the address field write the name of the share you want to
## connect to.  Useful ones are

## * `smb://fi--san03.dide.ic.ac.uk/homes/<username>` -- your home share
## * `smb://fi--didef2.dide.ic.ac.uk/tmp` -- the temporary share

## At some point in the process you should get prompted for your
## username and password, but I can't remember what that looks like.

## These directories will be mounted at `/Volumes/<username>` and
## `/Volumes/tmp` (so the last bit of the filename will be used as the
## mountpoint within `Volumes`).  There may be a better way of doing
## this, and the connection will not be restablished automatically so
## if anyone has a better way let me know.

## ## Linux

## This is what I have done for my computer and it seems to work,
## though it's not incredibly fast.  Full instructions are [on the Ubuntu community wiki](https://help.ubuntu.com/community/MountWindowsSharesPermanently).

## First, install cifs-utils

## ```
## sudo apt-get install cifs-utils
## ```

## In your `/etc/fstab` file, add

## ```
## //fi--san03/homes/<dide-username> <home-mount-point> cifs uid=<local-userid>,gid=<local-groupid>,credentials=/home/<local-username>/.smbcredentials,domain=DIDE,sec=ntlmssp,iocharset=utf8 0  0
## //fi--didef2/tmp <tmp-mount-point> cifs uid=<local-userid>,gid=<local-groupid>,credentials=/home/<local-username>/.smbcredentials,domain=DIDE,vers=2.0,sec=ntlmssp,iocharset=utf8 0  0
## ```

## where:

## - `<dide-username>` is your dide username without the `DIDE\` bit.
## - `<local-username>` is your local username (i.e., `echo $USER`).
## - `<local-userid>` is your local numeric user id (i.e. `id -u $USER`)
## - `<local-groupid>` is your local numeric group id (i.e. `id -g $USER`)
## - `<home-mount-point>` is where you want your DIDE home directory mounted
## - `<tmp-mount-point>` is where you want the DIDE temporary directory mounted

## **please back this file up before editing**.

## So for example, I have:

## ```
## //fi--san03/homes/rfitzjoh /home/rich/net/home cifs uid=1000,gid=1000,credentials=/home/rich/.smbcredentials,domain=DIDE,sec=ntlmssp,iocharset=utf8 0  0
## //fi--didef2/tmp /home/rich/net/temp cifs uid=1000,gid=1000,credentials=/home/rich/.smbcredentials,domain=DIDE,sec=ntlmssp,iocharset=utf8 0  0
## ```

## The file `.smbcredentials` contains

## ```
## username=<dide-username>
## password=<dide-password>
## ```

## and set this to be chmod 600 for a modicum of security, but be
## aware your password is stored in plaintext.

## This set up is clearly insecure.  I believe if you omit the
## credentials line you can have the system prompt you for a password
## interactively, but I'm not sure how that works with automatic
## mounting.

## Finally, run

## ```
## mount -a
## ```

## to mount all drives and with any luck it will all work and you
## don't have to do this until you get a new computer.

## # Running out of place

## The instructions above require that you are running on a network
## drive.  This might be inconvenient for people who run off the
## private network (e.g., mac users) or where you want to run things
## on the cluster part way through a project and don't want to copy
## everything over to a network drive.

## In this case there is (experimental) support for running "out of
## place" where the interaction with the cluster happens in a
## different directory to where your R session is running and where
## your files reside.  The wrinkle is getting the files you need
## synchronised.

## To do the syncronisation we use `rsync` via the
## [`syncr`](https://github.com/mrc-ide/syncr) package  Install it
## with:
##
## ```r
## drat:::add("mrc-ide")
## install.packages("syncr")
## ```

## Then, when constructing the queue, you need to specify a working
## directory for the cluster that is on the shared drive.
##
## ```r
## workdir <- "Q:/cluster/context"
## didehpc::didehpc_config_global(workdir = workdir)
## ```

## When you construct the context, that needs to be on a network
## share, so you might write:
##
## ```r
## root <- file.path(workdir, "contexts")
## ctx <- context::context_save(root, packages = "ape", sources = "mysources.R")
## ```

## Then construct the queue as normal.
##
## ```r
## obj <- didehpc::queue_didehpc(ctx)
## ```

## This will automatically syncronise the sources, copying them if
## they need updating.

## You can also specify additional files to synchronise with the
## `sync` argument to `queue_didehpc`.

## If you had other files to synchronise they would be listed with the
## argument `sync` to `queue_didehpc`.  You can update the remote
## files by running
##
## ```r
## obj$sync_files()
## ```

## at any time.
