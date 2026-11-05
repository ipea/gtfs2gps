# Animate public transport vehicles from a GTFS feed with gtfs2gps + gganimate
#
# Part 1 is self-contained: it uses the Fortaleza sample feed shipped with
# gtfs2gps and produces a simple animated map of vehicle positions.
# Part 2 builds the tilted "layer cake" map (city boundary, income, job access,
# PT network, moving vehicles). It downloads data with {geobr} and {aopdata}.
#
# packages needed beyond gtfs2gps:
# install.packages(c("ggplot2", "gganimate", "gifski", "ggnewscale", "geobr", "aopdata"))

library(gtfs2gps)
library(data.table)
library(ggplot2)
library(gganimate)


###### 1. Prepare data -----------------------------------------------------

# I'm using the sample GTFS, but you can point to a local file instead
gtfs_file <- system.file("extdata/fortaleza.zip", package = "gtfs2gps")
gtfs_raw <- gtfs2gps::read_gtfs(gtfs_file)

# # keep trips running between 7am and 8am
# gtfs <- gtfstools::filter_by_time_of_day(gtfs_raw, from = "07:00:00", to = "08:00:00")

# # select a sample of n routes (the sample feed has fewer than 80 routes)
# set.seed(42)
# all_routes <- unique(gtfs$routes$route_id)
# nroutes <- min(80, length(all_routes))
# myroutes <- sample(x = all_routes, size = nroutes, replace = FALSE)
# gtfs <- gtfstools::filter_by_route_id(gtfs, route_id = myroutes)

# route geometries
routes <- gtfstools::get_shapes_geometry(gtfs_raw)

# convert GTFS to a GPS-like data.table (one row per vehicle position)
gps <- gtfs2gps::gtfs2gps(gtfs_raw, spatial_resolution = 300, parallel = TRUE)
gps <- gps[!is.na(timestamp)]
gps <- gps[timestamp %between% c(as.ITime("07:00:00"), as.ITime("20:00:00"))]

# gganimate needs a continuous time variable. as.POSIXct() on an ITime gives
# a POSIXct in UTC, so the frame label is formatted in UTC below as well;
# this avoids the "+ 10800" time zone hack
gps[, time := as.POSIXct(timestamp, tz = "UTC")]


###### 2. Simple animation ---------------------------------------------------

anim_simple <- ggplot() +
  geom_sf(data = routes, color = "gray80", linewidth = 0.3) +
  geom_point(
    data = gps,
    aes(x = shape_pt_lon, y = shape_pt_lat, color = shape_id),
    size = 1,
    alpha = 0.7,
    show.legend = FALSE
  ) +
  scale_color_viridis_d() +
  theme_void() +
  theme(plot.background = element_rect(fill = "white", color = "white")) +

  # gganimate specifications
  labs(title = 'Time: {format(frame_time, "%H:%M", tz = "UTC")}') +
  transition_time(time) +
  shadow_wake(wake_length = 0.015, alpha = FALSE) +
  ease_aes("linear")

anim_save(
  filename = "./tests_rafa/gtfs_fortaleza_full.gif",
  animation = anim_simple,
  nframes = 200,
  fps = 20,
  width = 600,
  height = 600,
  renderer = gganimate::gifski_renderer()
)


###### 3. Tilted "layer cake" animation -------------------------------------

# Shear and rotate geometries so each layer looks like a tilted sheet, then
# shift it vertically by y_add to stack the layers
rotate_data <- function(data, x_add = 0, y_add = 0) {
  shear_matrix <- matrix(c(2, 1.2, 0, 1), 2, 2)
  rotate_matrix <- matrix(
    c(cos(pi / 20), sin(pi / 20), -sin(pi / 20), cos(pi / 20)),
    2,
    2
  )

  geom <- sf::st_geometry(data) * shear_matrix * rotate_matrix + c(x_add, y_add)
  sf::st_geometry(data) <- sf::st_set_crs(geom, NA)
  data
}

# city boundary and accessibility data (Fortaleza, 2019)
city <- geobr::read_municipality(code_muni = 2304400, year = 2010)
aop <- aopdata::read_access(
  city = "for",
  mode = "public_transport",
  peak = TRUE,
  year = 2019,
  geometry = TRUE
)
aop <- subset(aop, P001 > 0)

# rotate vehicle positions and bring them back to a data.frame of points
gps_points <- sfheaders::sf_point(
  gps,
  x = "shape_pt_lon",
  y = "shape_pt_lat",
  keep = TRUE
)
sf::st_crs(gps_points) <- 4326
gps_points_r <- rotate_data(gps_points, y_add = 0.3)
gps_points_df <- sfheaders::sf_to_df(gps_points_r, fill = TRUE)

# annotation parameters
x <- -80.92
clr <- "gray40"
sz <- 4

anim_layers <- ggplot() +

  # city boundary
  geom_sf(
    data = rotate_data(city, y_add = 0.03),
    color = "gray90",
    fill = "gray90",
    show.legend = FALSE
  ) +
  annotate(
    "text",
    label = "City boundary",
    x = x,
    y = 9.10,
    hjust = 0,
    color = clr,
    size = sz
  ) +

  # population income
  geom_sf(
    data = rotate_data(aop, y_add = 0.1),
    aes(fill = R001),
    color = NA,
    show.legend = FALSE
  ) +
  scale_fill_viridis_c(option = "E") +
  annotate(
    "text",
    label = "Income",
    x = x,
    y = 9.18,
    hjust = 0,
    color = clr,
    size = sz
  ) +

  # employment accessibility
  ggnewscale::new_scale_fill() +
  geom_sf(
    data = rotate_data(aop, y_add = 0.2),
    aes(fill = CMATT60),
    color = NA,
    show.legend = FALSE
  ) +
  scale_fill_viridis_c(option = "inferno") +
  annotate(
    "text",
    label = "Job access",
    x = x,
    y = 9.25,
    hjust = 0,
    color = clr,
    size = sz
  ) +

  # public transport routes
  geom_sf(
    data = rotate_data(routes, y_add = 0.3),
    color = "gray80",
    alpha = 0.4,
    show.legend = FALSE
  ) +
  annotate(
    "text",
    label = "Public transport \nnetwork",
    x = x,
    y = 9.35,
    hjust = 0,
    color = clr,
    size = sz
  ) +

  # public transport vehicles
  geom_point(
    data = gps_points_df,
    aes(x = x, y = y, color = shape_id),
    size = 0.8,
    alpha = 0.5,
    show.legend = FALSE
  ) +
  scale_color_viridis_d() +
  theme_void() +
  coord_sf(xlim = c(-81.5, -80.8)) +
  theme(
    plot.background = element_rect(fill = "white", color = "white"),
    plot.caption = element_text(color = "gray30")
  ) +

  # gganimate specifications
  labs(
    title = 'Time: {format(frame_time, "%H:%M", tz = "UTC")}',
    caption = "Image by @UrbanDemog"
  ) +
  transition_time(time) +
  shadow_wake(wake_length = 0.015, alpha = FALSE) +
  ease_aes("linear")

anim_save(
  filename = "./tests_rafa/gtfs_fortaleza_layers.gif",
  animation = anim_layers,
  nframes = 200,
  fps = 20,
  width = 800,
  height = 800,
  renderer = gganimate::gifski_renderer()
)
