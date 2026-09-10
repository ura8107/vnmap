# Run from the package root after the two industrial-park data builds.
# pkgload is a development-only dependency; installed-package users can use
# library(vnmap) and the exported APIs directly instead.
pkgload::load_all('.', quiet = TRUE)
library(ggplot2)
parks <- industrial_parks(category = NULL, crs = 4326)
points <- industrial_parks(category = NULL, geometry = 'point', crs = 4326)
xy <- sf::st_coordinates(points)
flat <- sf::st_drop_geometry(parks)
flat$longitude <- xy[,1]; flat$latitude <- xy[,2]
output <- 'output/industrial-parks'
dir.create(output, recursive = TRUE, showWarnings = FALSE)
write.csv(flat, file.path(output, 'mapped-sites.csv'), row.names = FALSE, na = '')
write_industrial_parks(parks, file.path(output, 'industrial-parks.geojson'))
counts <- table(parks$category)
points$map_category <- ifelse(points$category %in% c('industrial_park','export_processing_zone'),
  'Industrial park / EPZ', ifelse(points$category == 'industrial_cluster', 'Industrial cluster', 'Hi-tech park'))
p <- plot_vnmap(fill = '#f0f1ed', color = '#c4c9c3', linewidth = .18) +
  geom_sf(data = sf::st_transform(points, vnmap_crs()), aes(color = map_category),
    size = 1.55, alpha = .8, inherit.aes = FALSE) +
  scale_color_manual(values = c('Industrial park / EPZ' = '#166b70',
    'Industrial cluster' = '#c8772b', 'Hi-tech park' = '#76528b'), name = NULL) +
  labs(title = 'Vietnam industrial sites',
    subtitle = sprintf('%s mapped sites | Source reconciliation: 10 September 2026', nrow(parks)),
    caption = paste('Mapped subset; source lists include unresolved and planned records.',
      'Markers are representative locations, not legal boundaries or proof of operation.',
      'Sources: OpenStreetMap contributors (ODbL); Invest Vietnam; vnmap provincial boundaries.', sep = '\n')) +
  theme(plot.background = element_rect(fill = '#fafbf8', color = NA),
    panel.background = element_rect(fill = '#fafbf8', color = NA),
    plot.title = element_text(size = 23, face = 'bold', color = '#203c40'),
    plot.subtitle = element_text(size = 11, color = '#53696a', margin = margin(b = 15)),
    plot.caption = element_text(size = 8, hjust = 0, color = '#53696a', lineheight = 1.3),
    legend.position = 'bottom', legend.text = element_text(size = 10),
    plot.margin = margin(25,25,20,25))
ggsave(file.path(output, 'industrial-parks-map.png'), p, width = 9, height = 12, dpi = 180)
