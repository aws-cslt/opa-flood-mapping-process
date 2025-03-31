setwd(funr::get_script_path())
source("cube-utils.r")
gdalcubes_options(parallel = TRUE)
args <- commandArgs(trailingOnly = TRUE)
error_msg <-
  "An unexpected error occurred when executing the flood mapping process."

tryCatch({
  if (length(args) < 8) {
    error_msg <- "At least eight arguments must be supplied to the process."
    stop(error_msg, call. = FALSE)
  }
  if (length(args) > 10) {
    res <- system(paste("Rscript StacCubeCreation.r",
                        args[7], args[3], args[4], args[5], args[6], args[10], args[11], sep = " "))
  } else if (length(args) == 10) {
    res <- system(paste("Rscript StacCubeCreation.r",
                        args[7], args[3], args[4], args[5], args[6], args[10], sep = " "))
  } else {
    res <- system(paste("Rscript StacCubeCreation.r",
                        args[7], args[3], args[4], args[5], args[6], sep = " "))
  }

  if (res == "1") {
    error_msg <- "An unexpected error occured with harvesting."
    + " Ensure the bounding box is within bounds of the data"
    stop(error_msg)
  }

  uuid <- args[1]
  output_format <- args[2]
  sea_rise <- as.double(args[8])

  result <- GetCube("NewStacCube.json")
  dimensions <- dimensions(result)
  include_tide <- TRUE

  if (length(args) >= 9 && toupper(args[9]) == "FALSE") {
    include_tide <- FALSE
  }

  if (((dimensions$x$low > as.double(args[3]))
       || (dimensions$x$low > as.double(args[5])))
      || ((dimensions$x$high < as.double(args[3]))
          || (dimensions$x$high < as.double(args[5])))
      || ((dimensions$y$high < as.double(args[4]))
          || (dimensions$y$high < as.double(args[6])))
      || ((dimensions$y$low > as.double(args[4]))
          || (dimensions$y$low > as.double(args[6])))) {
    error_msg <- "Bounding box out of bounds of the data."
    stop(error_msg)
  } else {
    new_dimensions <- c(args[3], args[4],
                        args[5], args[6], dimensions$t$low, dimensions$t$high)
    result <- CropCubeWithTime(result, new_dimensions)

    dimensions <- dimensions(result)
    if (output_format == "image") {
      blue <- paste("(", sea_rise, "> dtm) * 255")
      green <- "0"
      red <- paste("(", sea_rise, "<= dtm) * 255")
      if (include_tide) {
        alpha <- paste("((((TRCLASS <= 1 && (", sea_rise, " + 2 > dtm)) || 
				(TRCLASS <= 2 && (", sea_rise, " + 4 > dtm)) || 
				(TRCLASS <= 3 && (", sea_rise, " + 6 > dtm)) || 
				(TRCLASS <= 4 && (", sea_rise, " + 9 > dtm)) || 
				(TRCLASS <= 5 && (", sea_rise, " + 12 > dtm))) && (dtm >= 0))) * 255")
        rgba_cube <- apply_pixel(result, c(red, green, blue, alpha),
                                 c("r", "g", "b", "a"))
      } else {
		alpha <- paste("(((", sea_rise, "> dtm) && (dtm >= 0))) * 255")
        rgba_cube <- apply_pixel(result, c("0", green, blue, alpha),
                                 c("r", "g", "b", "a"))
      }
      pack_func <- pack_minmax(type = "uint8", 0, 255)
      WriteOutput(rgba_cube, uuid, output_format, pack_func = pack_func)

    } else if (output_format == "shape") {
      flood_area <- paste("((", sea_rise, ">= dtm) && (0 <= dtm)) * 255")
      if (include_tide) {
        tide_area <- paste("((((TRCLASS <= 1 && (", sea_rise, " + 2 > dtm)) || 
				(TRCLASS <= 2 && (", sea_rise, " + 4 > dtm)) || 
				(TRCLASS <= 3 && (", sea_rise, " + 6 > dtm)) || 
				(TRCLASS <= 4 && (", sea_rise, " + 9 > dtm)) || 
				(TRCLASS <= 5 && (", sea_rise, " + 12 > dtm))) 
				&& (dtm > ", sea_rise, "))) * 255")
        final_cube <- filter_pixel(apply_pixel(result, c(flood_area, tide_area)
                                               , c("b", "r"))
                                   , "((0 < b) || (b < r))")
      } else {
        final_cube <- filter_pixel(apply_pixel(result, c(flood_area),
                                               c("b")), "((0 < b))")
      }
      pack_func <- pack_minmax(type = "uint8", 0, 255)
      WriteOutput(final_cube, uuid, output_format, pack_func = pack_func)
    } else if (output_format == "kml") {
      flood_area <- paste("((", sea_rise, ">= dtm) && (0 <= dtm)) * 255")
      if (include_tide) {
        tide_area <- paste("((((TRCLASS <= 1 && (", sea_rise, " + 2 > dtm)) || 
				(TRCLASS <= 2 && (", sea_rise, " + 4 > dtm)) || 
				(TRCLASS <= 3 && (", sea_rise, " + 6 > dtm)) || 
				(TRCLASS <= 4 && (", sea_rise, " + 9 > dtm)) || 
				(TRCLASS <= 5 && (", sea_rise, " + 12 > dtm))) 
				&& (dtm > ", sea_rise, "))) * 255")
        final_cube <- filter_pixel(apply_pixel(result, c(flood_area, tide_area),
                                               c("b", "r")),
                                   "((0 < b) || (b < r))")
      } else {
        final_cube <- filter_pixel(apply_pixel(result, c(flood_area),
                                               c("b")), "((0 < b))")
      }
      pack_func <- pack_minmax(type = "uint8", 0, 255)
      WriteOutput(final_cube, uuid, output_format, pack_func = pack_func)
    } else if (output_format == "geojson") {
      flood_area <- paste("((", sea_rise, ">= dtm) && (0 <= dtm)) * 255")
      if (include_tide) {
        tide_area <- paste("((((TRCLASS <= 1 && (", sea_rise, " + 2 > dtm)) || 
				(TRCLASS <= 2 && (", sea_rise, " + 4 > dtm)) || 
				(TRCLASS <= 3 && (", sea_rise, " + 6 > dtm)) || 
				(TRCLASS <= 4 && (", sea_rise, " + 9 > dtm)) || 
				(TRCLASS <= 5 && (", sea_rise, " + 12 > dtm))) 
				&& (dtm > ", sea_rise, "))) * 255")
        final_cube <- filter_pixel(apply_pixel(result, c(flood_area, tide_area),
                                               c("b", "r")),
                                   "((0 < b) || (b < r))")
      } else {
        final_cube <- filter_pixel(apply_pixel(result, c(flood_area),
                                               c("b")), "((0 < b))")
      }
      pack_func <- pack_minmax(type = "uint8", 0, 255)
      WriteOutput(final_cube, uuid, output_format, pack_func = pack_func)
    }
  }
}, error = function(e) {
  WriteError(args[1], error_msg)
})
