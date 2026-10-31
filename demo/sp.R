
library(gtfs2gps)
library(dplyr)

sp <- read_gtfs(system.file("extdata/saopaulo.zip", package="gtfs2gps"))
names(sp)
sp$trips

sp_small <- gtfstools::filter_by_shape_id(sp, 53000:53020)

sp_small_sf <- gtfstools::get_shapes_geometry(sp_small)

sp_gps <- gtfs2gps(sp_small, parallel = TRUE)
sp_gps

sp_gps_sf <- gps_as_sf(sp_gps)
sp_gps_small <- sp_gps[1:60, ]

sp_gps_small_sf <- gps_as_sf(sp_gps_small)

plot(sf::st_geometry(sp_gps_small_sf), pch = 20)
plot(sf::st_geometry(sp_small_sf), col = "blue", add = TRUE)
plot(sf::st_geometry(sp_gps_sf), add = TRUE, pch = 20)
box()
