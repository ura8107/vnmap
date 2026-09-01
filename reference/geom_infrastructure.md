# Add infrastructure to a ggplot map

Add infrastructure to a ggplot map

## Usage

``` r
geom_infrastructure(
  data = NULL,
  type = NULL,
  status = NULL,
  province = NULL,
  include = NULL,
  class = NULL,
  service = NULL,
  geometry = c("any", "point", "line"),
  crs = vnmap_crs(),
  point_colour = "#2166ac",
  line_colour = "#4d4d4d",
  point_size = 1.8,
  line_width = 0.5,
  mapping = NULL,
  inherit.aes = FALSE,
  show.legend = NA,
  na.rm = FALSE
)
```

## Arguments

- data:

  Optional infrastructure `sf` object.

- type:

  Optional values among `"port"`, `"aerodrome"`, `"border_control"`,
  `"expressway"`, `"national_highway"`, and `"railway"`.

- status:

  Optional lifecycle status. Supported values are `"operational"`,
  `"under_construction"`, `"planned"`, `"disused"`, `"abandoned"`, and
  `"unknown"`.

- province:

  Optional current province names or codes.

- include:

  Optional infrastructure IDs or names.

- class:

  Optional facility subclass, such as `"military_aerodrome"`,
  `"fishing_port"`, `"rail_yard"`, or `"rail_siding"`.

- service:

  Optional service classification, such as
  `"commercial_service_candidate"`, `"service=yard"`, or `"usage=main"`.

- geometry:

  `"any"`, `"point"`, or `"line"`.

- crs:

  Output CRS.

- point_colour, line_colour:

  Colours for points and lines.

- point_size, line_width:

  Sizes for points and lines.

- mapping:

  Optional aesthetics. When omitted, facility points use shape and
  network lines use linetype to distinguish `infrastructure_type`.

- inherit.aes:

  Whether to inherit aesthetics from the parent plot.

- show.legend:

  Whether this layer should appear in legends.

- na.rm:

  Whether missing values are silently removed.

## Value

A list of ggplot2 layers.
