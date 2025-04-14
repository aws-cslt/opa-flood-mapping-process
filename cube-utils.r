library("gdalcubes")
library(RCurl)
library(jsonlite)
library(stringr)
library(DBI)
library(RPostgreSQL)
library(rstac)

# Static variables
base_dir <- "/opt/"
cubes_dir_no_slash <- paste(base_dir, "cubes", sep="")
cubes_dir <- paste(cubes_dir_no_slash, "/", sep="")
data_dir <- paste(base_dir, "data/", sep="")
streaming_dir <- paste(base_dir, "streaming", sep="")
downsampled_x <- 1024
downsampled_y <- 1024
downsampled_pixel_count <- downsampled_x * downsampled_y

#gdalcubes_options(cache=TRUE, streaming_dir=streaming_dir, default_chunksize=c(1,256,256))
#gdalcubes_options(cache=TRUE, default_chunksize=c(1,256,256), use_overview_images=TRUE)
gdalcubes_options(cache=TRUE, streaming_dir=streaming_dir, default_chunksize=c(1,256,256), use_overview_images=TRUE)
#options(warn=-1, messages=-1)


#' Returns the location on disk where gdalcubes are stored.
#'
#' @export
GetCubesDir <- function(){
        return(cubes_dir)
}

#' Returns the location on disk where source image data is stored.
#'
#' @export
GetDataDir <- function(){
        return(data_dir)
}

#' Returns a gdalcubes proxy cube object when given the name of a saved cube.
#'
#' @param The file name of a gdalcube saved to GetCubesDir as a json file. (include extensions)
#' @export
GetCube <- function(json_file_name){
        return(json_cube(path = paste(GetCubesDir(), json_file_name, sep="")))
}

#' Returns a gdalcubes proxy cube object when given the name of a cube saved as a NCDF.
#'
#' @param The file name of a gdalcube saved to GetCubesDir as a ncdf file. (include extensions)
#' @export
GetCubeNcdf <- function(ncdf_file_name){
        return(ncdf_cube(paste(GetCubesDir(), ncdf_file_name, sep="")))
}

#' Returns a gdalcubes proxy cube object when given the name of a saved cube and cropped to the given bbox.
#'
#' @param The file name of a gdalcube saved to GetCubesDir as a json file. (include extensions)
#' @param Array of a size 4 for cropping the cube. [min_lon, min_lat, max_lon, max_lat]
#' @export
GetCroppedCube <- function(json_file_name, args) {
        min_lon = as.double(args[1])
        min_lat = as.double(args[2])
        max_lon = as.double(args[3])
        max_lat = as.double(args[4])

        query = list(left=min_lon, right=max_lon, bottom=min_lat, top=max_lat)

        return (GetCube(json_file_name)[query])
        #return (GetCube(json_file_name) |>
        #         crop(extent=query, snap="near"))        
}

#' Returns a cropped gdalcubes proxy cube object when given a gdalcubes proxy cube object and a given bbox.
#'
#' @param The cube to crop.
#' @param Array of a size 4 for cropping the cube. [min_lon, min_lat, max_lon, max_lat]
#' @export
CropCube <- function(cube, args) {
	min_lon = as.double(args[1])
        min_lat = as.double(args[2])
        max_lon = as.double(args[3])
        max_lat = as.double(args[4])

        query = list(left=min_lon, right=max_lon, bottom=min_lat, top=max_lat)

        return (cube[query])
}

#' Returns a cropped gdalcubes proxy cube object when given a gdalcubes proxy cube object and a given bbox (including start/end time).
#'
#' @param The cube to crop.
#' @param Array of a size 6 for cropping the cube. [min_lon, min_lat, max_lon, max_lat, low_time, high_time]
#' @export
CropCubeWithTime <- function(cube, args) {
	min_lon = as.double(args[1])
        min_lat = as.double(args[2])
        max_lon = as.double(args[3])
        max_lat = as.double(args[4])
		low_time = args[5]
		high_time = args[6]

        query = list(left=min_lon, right=max_lon, bottom=min_lat, top=max_lat, t0=low_time, t1=high_time)
		cropped = crop(cube, extent=query)
		return(slice_time(cropped, datetime=high_time))
}

#' Returns a gdalcubes proxy cube object when given the name of a saved cube and cropped to the given bbox.
#'
#' @param The file name of a gdalcube saved to GetCubesDir as a ncdf file. (include extensions)
#' @param Array of a size 4 for cropping the cube. [min_lon, min_lat, max_lon, max_lat]
#' @export
GetCroppedCubeNcdf <- function(file_name, args) {
        min_lon = as.double(args[1])
        min_lat = as.double(args[2])
        max_lon = as.double(args[3])
        max_lat = as.double(args[4])

        query = list(left=min_lon, right=max_lon, bottom=min_lat, top=max_lat)

        return (GetCubeNcdf(file_name)[query])
        #return (GetCube(json_file_name) |>
        #         crop(extent=query, snap="near"))
}

#' Returns A proxy data cube that will have the proper dimensions from the downsampling.
#'
#' @param The cube that will be downsampled.
#' @export The new cube with new dimensions.
GetDownsampledCube <- function(cube, args, width=downsampled_x, height=downsampled_y) {
	#return (cube)
	#min_lon = as.double(args[1])
        #min_lat = as.double(args[2])
        #max_lon = as.double(args[3])
        #max_lat = as.double(args[4])
	#size_x = (max_lon - min_lon) / downsampled_x
	#size_y = (max_lat - min_lat) / downsampled_y

	dims = dimensions(cube)
#### Fact
#downsampled_pixel_count

#	cube_pixel_count = dims$x$count * dims$y$count
#	if(cube_pixel_count < downsampled_pixel_count) return (cube)

#	return (aggregate_space(cube,,,method="median", fact=as.integer(ceiling(cube_pixel_count/downsampled_pixel_count))))

#####	

	pixel_size_x = (dims$x$high - dims$x$low) / width
	pixel_size_y = (dims$y$high - dims$y$low) / height
	
	cube_dx = dims$x$pixel_size
	cube_dy = dims$y$pixel_size
	
	if(dims$x$count < downsampled_x) pixel_size_x = dims$x$pixel_size
	if(dims$y$count < downsampled_y) pixel_size_y = dims$y$pixel_size
	
	return (aggregate_space(cube, pixel_size_x, pixel_size_y, method="median"))
}

#' Returns A proxy data cube that will have the proper dimensions from the downsampling.
#'
#' @param The cube that will be downsampled.
#' @export The new cube with new dimensions.
GetTimeSlice <- function(cube, dateTime) {
        return (slice_time(cube, datetime=dateTime))
}


#' Saves the given gdalcubes proxy cube to disk.
#'
#' @param The proxy cube to save
#' @param The file name to use when saving the given cube to disk
#' @export
SaveCube <- function(cube, file_name){
	json_file <- paste(GetCubesDir(), file_name, sep="")
	file.create(json_file)
	as_json(cube, json_file)
}

#' Saves the given gdalcubes proxy cube to disk as a ncdf.
#'
#' @param cube The proxy cube to save
#' @param file_name The file name to use when saving the given cube to disk
#' @export
SaveCubeNcdf <- function(cube, file_name, chunked=FALSE){
        ncdf_file <- paste(GetCubesDir(), file_name, sep="")
        write_ncdf(cube, fname = ncdf_file, overwrite = TRUE, write_json_descr = TRUE, with_VRT = FALSE, chunked=chunked)
}

#' Writes the given gdalcubes proxy cube to standard out based on the give output_format
#'
#' @param cube The proxy cube to write
#' @param output_format the format to return the cube. (raw, cube, image)
#' @param pack_func if writing the cube as an image, can optionally provide a pack_minmax function
#' @export
WriteOutput <- function(cube, uuid, output_format, pack_func=NULL, metadata=NULL) {
	
	gdalcubes_options(show_progress=TRUE);
	status_loc = paste(cubes_dir, uuid, "-status", sep="");
	status <- file(status_loc)
	sink(status);
	sink(status, type = "message")
	if(output_format == "cube") {
		newcube_name = paste(uuid, "-cube.nc", sep="")
		SaveCubeNcdf(cube, newcube_name);
		data = toJSON(list(path=newcube_name, metadata=metadata), auto_unbox=TRUE);
	} else if (output_format == "image") {
		result_file_name = paste(uuid, "-result", sep="")
		tif_loc = write_tif(cube, dir=cubes_dir_no_slash, prefix=result_file_name, pack=pack_func)
		data = toJSON(list(path=tif_loc), auto_unbox=TRUE)
	} else if (output_format == "shape") {
		result_file_name = paste(uuid, "-result", sep="")
		tif_loc = write_tif(cube, dir=cubes_dir_no_slash, prefix=result_file_name, pack=pack_func)
		shp_loc = paste(GetCubesDir(), uuid, "-vectorResult.shp", sep="")
		dbf_loc = paste(GetCubesDir(), uuid, "-vectorResult.shp", sep="")
		shx_loc = paste(GetCubesDir(), uuid, "-vectorResult.shp", sep="")
		prj_loc = paste(GetCubesDir(), uuid, "-vectorResult.shp", sep="")
		
		#overwrite parameter in gdal not working, delete file if it exists before writing
		unlink(shp_loc)
		unlink(dbf_loc)
		unlink(shx_loc)
		unlink(prj_loc)
		
		shz_loc = paste(GetCubesDir(), uuid, "-vectorResult.shz", sep="")
		system(paste("gdal_polygonize.py ", tif_loc, " -overwrite ", shp_loc, sep=""))
		unlink(shz_loc)
		system(paste("ogr2ogr -f \"ESRI Shapefile\" -skipfailures ", shz_loc, " ", shp_loc, sep=""))
		data = toJSON(list(path=shz_loc), auto_unbox=TRUE)
	} else if (output_format == "kml") {
		result_file_name = paste(uuid, "-result", sep="")
		tif_loc = write_tif(cube, dir=cubes_dir_no_slash, prefix=result_file_name, pack=pack_func)
		kml_loc = paste(GetCubesDir(), uuid, "-vectorResult.kml", sep="")
		#overwrite parameter in gdal not working, delete file if it exists before writing
		unlink(kml_loc)

		system(paste("gdal_polygonize.py ", tif_loc, " ", kml_loc, sep=""))
		system(paste("python3 editKML.py ", kml_loc, sep=""))
		data = toJSON(list(path=kml_loc), auto_unbox=TRUE)
	} else if (output_format == "geojson") {
		result_file_name = paste(uuid, "-result", sep="")
		tif_loc = write_tif(cube, dir=cubes_dir_no_slash, prefix=result_file_name, pack=pack_func)
		geojson_temp_loc = paste(GetCubesDir(), uuid, "-vectorResultTemp.geojson", sep="")
		geojson_loc = paste(GetCubesDir(), uuid, "-vectorResult.geojson", sep="")
		#overwrite parameter in gdal not working, delete file if it exists before writing
		unlink(geojson_loc)
		system(paste("gdal_polygonize.py ", tif_loc, " ", geojson_temp_loc, " -overwrite", sep=""))
		system(paste("python3 addStyleToGeoJson.py", geojson_temp_loc))
		system(paste("ogr2ogr ", "-f", "GeoJSON", "-lco RFC7946=YES", geojson_loc, geojson_temp_loc, sep=" "))
		#This deletes the temp file
		unlink(geojson_temp_loc)
		data = toJSON(list(path=geojson_loc), auto_unbox=TRUE)
	}
	finished_loc = paste(cubes_dir, uuid, "-finished.json", sep="");
	file <- file(finished_loc);
	write(data, file);
	unlink(file);
}

#' Writes the given gdalcubes proxy cube to standard out based on the give output_format
#'
#' @param cube The proxy cube to write
#' @param output_format the format to return the cube. (raw, cube, image)
#' @param pack_func if writing the cube as an image, can optionally provide a pack_minmax function
#' @export
ReadOutput <- function(location, output_format) {
        if(output_format == "cube") {
		finished_loc = paste(cubes_dir, location, "-finished.json", sep="");
		lines = readLines(finished_loc);
                file_string = paste(lines, collapse= "\n");
                write(file_string, stdout())
        } else if (output_format == "image") {
		finished_loc = paste(cubes_dir, location, "-finished.json", sep="");
		finished_json = read_json(finished_loc);
		tempdir = tempdir();
		png_loc = paste(tempdir,"/output.png",sep="")
                # quietly convert tif to png and ignore warnings
                system(paste("gdal_translate -q -a_nodata none  -of png", finished_json$path, png_loc, "> /dev/null 2>&1"))
                b64 = base64Encode(readBin(png_loc, "raw", file.info(png_loc)[1, "size"]), "txt")
                write(b64, stdout())
        }
}

#' Writes the given gdalcubes proxy cube to standard out based on the give output_format
#'
#' @param cube The proxy cube to write
#' @param output_format the format to return the cube. (raw, cube, image)
#' @param pack_func if writing the cube as an image, can optionally provide a pack_minmax function
#' @export
GetStatus <- function(location) {
        finished_loc = paste(cubes_dir, location, "-finished.json", sep="");
        status_loc = paste(cubes_dir, location, "-status", sep="");
	error_loc = paste(cubes_dir, location, "-error", sep="");
	if(file.exists(finished_loc)){
		write("{\"status\":\"finished\", \"progress\":100}", stdout());
	} else if(file.exists(error_loc)){
                lines = readLines(error_loc);
                file_string = paste(lines, collapse= "\n");
                write(paste("{\"status\":\"failed\", \"progress\":100, \"error\":\"", file_string, "\"}", sep=""), stdout());
        } else if(file.exists(status_loc)){
		lines = readLines(status_loc);
		file_string = paste(lines, collapse= "\n");
		values = str_extract(lines, "\\] ([0-9]*) %", 1);
		progress = values[length(values)]
		write(paste("{\"status\":\"running\", \"progress\":", progress, "}", sep=""), stdout());
	} else {
		write("{\"status\":\"running\", \"progress\":0}", stdout());
	}
}

WriteError <- function(location, errorMessage) {
	error_loc = paste(cubes_dir, location, "-error", sep="");
        error <- file(error_loc)
	write(errorMessage, error);
}
