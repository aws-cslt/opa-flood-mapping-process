FROM debian:12.10-slim
RUN apt update
RUN apt install -y r-base
RUN apt install -y python3
RUN apt-get install -y gdal-bin
RUN apt-get install -y libgdal-dev
RUN apt-get install -y libhdf5-dev
RUN apt-get install -y libnetcdf-dev
RUN apt-get install -y libudunits2-dev
RUN R -e "install.packages('funr', dependencies=FALSE)"
RUN R -e "install.packages('curl', dependencies=FALSE)"
RUN R -e "install.packages('jsonlite', dependencies=FALSE)"
RUN R -e "install.packages('mime', dependencies=FALSE)"
RUN R -e "install.packages('sys', dependencies=FALSE)"
RUN R -e "install.packages('askpass', dependencies=FALSE)"
RUN R -e "install.packages('openssl', dependencies=FALSE)"
RUN R -e "install.packages('R6', dependencies=FALSE)"
RUN R -e "install.packages('httr', dependencies=FALSE)"
RUN R -e "install.packages('bitops', dependencies=FALSE)"
RUN R -e "install.packages('RCurl', dependencies=FALSE)"
RUN R -e "install.packages('BH', dependencies=FALSE)"
RUN R -e "install.packages('Rcpp', dependencies=FALSE)"
RUN R -e "install.packages('cli', dependencies=FALSE)"
RUN R -e "install.packages('glue', dependencies=FALSE)"
RUN R -e "install.packages('rlang', dependencies=FALSE)"
RUN R -e "install.packages('lifecycle', dependencies=FALSE)"
RUN R -e "install.packages('magrittr', dependencies=FALSE)"
RUN R -e "install.packages('stringi', dependencies=FALSE)"
RUN R -e "install.packages('vctrs', dependencies=FALSE)"
RUN R -e "install.packages('stringr', dependencies=FALSE)"
RUN R -e "install.packages('DBI', dependencies=FALSE)"
RUN R -e "install.packages('RPostgreSQL', dependencies=FALSE)"
RUN R -e "install.packages('crayon', dependencies=FALSE)"
RUN R -e "install.packages('class', dependencies=FALSE)"
RUN R -e "install.packages('proxy', dependencies=FALSE)"
RUN R -e "install.packages('e1071', dependencies=FALSE)"
RUN R -e "install.packages('KernSmooth', dependencies=FALSE)"
RUN R -e "install.packages('classInt', dependencies=FALSE)"
RUN R -e "install.packages('wk', dependencies=FALSE)"
RUN R -e "install.packages('s2', dependencies=FALSE)"
RUN R -e "install.packages('units', dependencies=FALSE)"
RUN R -e "install.packages('sf', dependencies=FALSE)"
RUN R -e "install.packages('png', dependencies=FALSE)"
RUN R -e "install.packages('jpeg', dependencies=FALSE)"
RUN R -e "install.packages('rstac', dependencies=FALSE)"
RUN R -e "install.packages('ncdf4', dependencies=FALSE)"
RUN R -e "install.packages('gdalcubes', dependencies=FALSE)"
RUN mkdir /opt/scripts
RUN mkdir /opt/streaming
RUN mkdir /opt/data
RUN mkdir /opt/data/CanCoastTidalRange
RUN mkdir /opt/cubes
COPY cube-utils.r /opt/scripts/
COPY cslt-query-COG-DataCube.r /opt/scripts/
COPY StacCubeCreation.r /opt/scripts/
COPY HandleProcess.py /opt/scripts/
COPY editKML.py /opt/scripts/
COPY flood-mapping-geojson-style-en.json /opt/scripts/
COPY flood-mapping-geojson-style-fr.json /opt/scripts/
COPY addStyleToGeoJson.py /opt/scripts/
COPY DEM.json /usr/local/lib/R/site-library/gdalcubes/formats/
COPY 20230710can_tide_interp.tif /opt/data/CanCoastTidalRange/
RUN apt-get install -y python3-websockets
RUN apt-get install -y python3-requests
CMD python3 /opt/scripts/HandleProcess.py