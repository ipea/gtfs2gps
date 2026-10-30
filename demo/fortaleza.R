
library(gtfs2gps)
library(dplyr)

fortaleza <- read_gtfs(system.file("extdata/fortaleza.zip", package="gtfs2gps"))
names(fortaleza)

ids <- fortaleza$shapes$shape_id %>% unique()
ids

fortaleza <- gtfstools::filter_by_shape_id(fortaleza, ids[1:4])

for_small_sf <- gtfstools::get_shapes_geometry(fortaleza)

srtmfile <- system.file("extdata/fortaleza-srtm.tif", package = "gtfs2gps")

for_gps <- gtfs2gps(fortaleza, parallel = TRUE) %>% append_height(srtmfile)

for_gps_sf <- gps_as_sfpoints(for_gps)
for_gps_sf$height <- for_gps$height

#write_sf(for_gps_sf, "for-gps2.shp")

for_gps_small <- for_gps

for_gps_small_sf <- gps_as_sfpoints(for_gps_small)

plot(sf::st_geometry(for_gps_small_sf), pch = 20)
plot(sf::st_geometry(for_small_sf), col = "blue", add = TRUE)
plot(sf::st_geometry(for_gps_sf), add = TRUE, pch = 20)
box()

# plotting GPS points with height

plot(for_gps_sf["height"], pch = 20)
