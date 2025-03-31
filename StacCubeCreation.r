setwd(funr::get_script_path())
source("cube-utils.r")
library(httr)
args <- commandArgs(trailingOnly = TRUE)

api_link <- "https://datacube.services.geo.ca/stac/api/search?collections"
pixel_limit <- 1000000

if (length(args) > 6) {
    pixel_limit <- as.numeric(args[7])
} else if (length(args) == 6) {
    api_link <- args[6]
}
stac_feature_collection <- stac(api_link)

stac_collection <- args[1]
dim <- 0.00001

bbox <- c(as.double(args[2]), as.double(args[3]),
          as.double(args[4]), as.double(args[5]))

items <- stac_feature_collection |>
  stac_search(collection = stac_collection, limit = 100, bbox = bbox) |>
  post_request()

# Creates appropriate dimension resolution given selected AOI
x_length <- (as.double(args[4]) - as.double(args[2])) / dim
y_length <- (as.double(args[5]) - as.double(args[3])) / dim
area <- x_length * y_length
new_dim <- ceiling(sqrt((area / pixel_limit))) * dim

unlink(paste(GetCubesDir(), "NewStacCube.db", sep = ""))
col <- stac_image_collection(items$features,
                             paste(GetCubesDir(), "NewStacCube.db", sep = ""))

tide_col <- paste(GetDataDir(),
                  "CanCoastTidalRange/20230710can_tide_interp.tif", sep = "") |>
  create_image_collection("DEM", paste(GetCubesDir(), "Can_Tide.db", sep = ""))

extent <- list(left = as.double(args[2]), right = as.double(args[4]),
               bottom = as.double(args[3]), top = as.double(args[5]),
               t0 = "2013-07-10", t1 = "2024-12-10")

view <- cube_view(extent = extent, nt = 1, dx = new_dim, dy = new_dim,
                  srs = "EPSG:4326", aggregation = "median",
                  resampling = "near")

new_cube_cube <- raster_cube(col, view)
tide_cube <- raster_cube(tide_col, view)

result <- rename_bands(join_bands(list(tide_cube, new_cube_cube),
                                  list("tide", "stac")),
                       tide.elevation = "TRCLASS",
                       stac.dtm = "dtm", stac.dsm = "dsm")

SaveCube(result, "NewStacCube.json")