test_that("write_gtfs", {
  
    # temp file
    poa2_zip <- tempfile(pattern = 'poa', fileext = '.zip')
  
  
    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))
    
    write_gtfs(poa, zipfile = poa2_zip)
    
    poa <- read_gtfs(poa2_zip)
    
    expect_type(poa, "list")
    expect_equal(length(poa), 7)
    
    expect_true(length(poa$agency) >= 1)
    expect_equal(length(poa$routes), 9)
    expect_equal(length(poa$stops), 6)
    expect_equal(length(poa$stop_times), 5)
    expect_equal(length(poa$shapes), 4)
    expect_equal(length(poa$trips), 4)
    expect_equal(length(poa$calendar), 10)
    
    expect_equal(dim(poa$shapes)[1], 1265)
    expect_equal(dim(poa$trips)[1], 387)
    
  # test with frequencies
    
    # temp file
    sp2_zip <- tempfile(pattern = 'sp2', fileext = '.zip')
    
    sp <- read_gtfs(system.file("extdata/saopaulo.zip", package="gtfs2gps"))
    
    write_gtfs(sp, zipfile = sp2_zip)
    
    sp <- read_gtfs(sp2_zip)
    
    expect_type(sp, "list")
    expect_equal(length(sp), 8)
    
    expect_equal(length(sp$agency), 5)
    expect_equal(length(sp$routes), 7)
    expect_equal(length(sp$stops), 5)
    expect_equal(length(sp$stop_times), 5)
    expect_equal(length(sp$shapes), 4)
    expect_equal(length(sp$trips),4)
    expect_equal(length(sp$calendar), 10)
    
    expect_equal(dim(sp$shapes)[1], 35886)
    expect_equal(dim(sp$trips)[1], 92)
})

test_that("write_gtfs respects overwrite", {
    poa_zip <- tempfile(pattern = 'poa_overwrite', fileext = '.zip')
    on.exit(unlink(poa_zip), add = TRUE)

    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))
    poa_small <- gtfstools::filter_by_shape_id(poa, "T2-1")
    expect_true(nrow(poa_small$trips) < nrow(poa$trips))
    poa_small_old <- data.table::copy(poa_small)

    # overwrite = FALSE on a new path: writes, returns the gtfs invisibly
    expect_invisible(result <- write_gtfs(poa, zipfile = poa_zip, overwrite = FALSE, quiet = TRUE))
    expect_s3_class(result, "dt_gtfs")
    expect_true(file.exists(poa_zip))
    size_before <- file.size(poa_zip)

    # overwrite = FALSE: error, and the existing file is left untouched
    expect_error(write_gtfs(poa_small, zipfile = poa_zip, overwrite = FALSE, quiet = TRUE),
                 class = "gtfs2gps_file_exists_error")
    expect_equal(file.size(poa_zip), size_before)

    # invalid arguments
    expect_error(write_gtfs(poa_small, zipfile = poa_zip, overwrite = NA, quiet = TRUE), "overwrite")
    expect_error(write_gtfs(poa_small, zipfile = poa_zip, overwrite = "no", quiet = TRUE), "overwrite")
    expect_error(write_gtfs(poa_small, zipfile = NULL, quiet = TRUE), "zipfile")
    expect_error(write_gtfs(poa_small, zipfile = c("a.zip", "b.zip"), overwrite = FALSE, quiet = TRUE), "zipfile")
    expect_error(write_gtfs(poa_small, zipfile = poa_zip, quiet = NA), "quiet")

    # overwrite = TRUE (default): the file is replaced
    write_gtfs(poa_small, zipfile = poa_zip, quiet = TRUE)
    expect_true(file.size(poa_zip) < size_before)
    expect_equal(nrow(read_gtfs(poa_zip)$trips), nrow(poa_small$trips))

    # input data is not modified
    expect_equal(poa_small, poa_small_old)
})

test_that("write_gtfs passes compression_level", {
    poa_zip <- tempfile(pattern = 'poa_level', fileext = '.zip')
    on.exit(unlink(poa_zip), add = TRUE)

    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

    write_gtfs(poa, zipfile = poa_zip, quiet = TRUE, compression_level = 1)
    expect_equal(nrow(read_gtfs(poa_zip)$trips), nrow(poa$trips))

    expect_error(write_gtfs(poa, zipfile = poa_zip, quiet = TRUE, compression_level = 10), "compression_level")
})
