
library(gtfs2gps)
library(dplyr)

poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps")) %>%
  gtfstools::filter_by_shape_id("T2-1")

names(poa)
sp$trips

poa_shp <- gtfstools::get_shapes_geometry(poa)
poa_stops <- gtfstools::get_stops_geometry(poa)

plot(sf::st_geometry(poa_shp))
plot(sf::st_geometry(poa_stops), col = "blue", add = TRUE)
box()

gps <- gtfs2gps(poa, parallel = TRUE)

gps_sf <- gps_as_sf(gps) %>%
  dplyr::filter(trip_id == "T2-1@1#520")

plot(sf::st_geometry(gps_sf))
