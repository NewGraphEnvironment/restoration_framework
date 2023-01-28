# need to determine which watershed groups UFN and LDN territory overlap
library(DBI)
library(tidyverse)
library(sf)

conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname = 'newgraph',
  host = 'localhost',
  port = Sys.getenv('PG_PORT'),
  user = 'postgres',
  password = 'postgres'
)

# ##listthe schemas in the database
DBI::dbGetQuery(conn,
                "SELECT schema_name
           FROM information_schema.schemata")

DBI::dbGetQuery(conn,
                "SELECT table_name
           FROM information_schema.tables")

DBI::dbGetQuery(conn,
                "SELECT count(*) FROM whse_basemapping.fwa_rivers_poly;")

# need to import both the territorial boundaries and see which watershd groups they overlap with

# bring in the shapefiles of the territorial boundaries

ufn <- sf::st_read('data/UFN Territory/UFN Territory.shp')

ufn <- ufn %>%
  st_transform(crs = 3005)

ldn <- sf::st_read('data/LDN Territory/LDNBoundary.shp')

ldn <-ldn %>%
  st_transform(crs = 3005)


ggplot() +
  geom_sf(data = ufn) +
  geom_sf(data = ldn)

# #
# query <- "SELECT * FROM whse_basemapping.fwa_watershed_groups_poly"
#
# wsg <-  sf::st_read(conn, query = query)

dbExecute(conn, "CREATE SCHEMA IF NOT EXISTS WORKING")
# load to database
sf::st_write(obj = ufn, dsn = conn, Id(schema= "working", table = "ufn"))
sf::st_write(obj = ldn, dsn = conn, Id(schema= "working", table = "ldn"))
# sf doesn't automagically create a spatial index or a primary key
dbExecute(conn, "CREATE INDEX ON working.ufn USING GIST (geometry)")
dbExecute(conn, "CREATE INDEX ON working.ldn USING GIST (geometry)")
# res <- dbSendQuery(conn, "ALTER TABLE working.misc ADD PRIMARY KEY (misc_point_id)")
# dbClearResult(res)

ufn_wsg <- DBI::dbGetQuery(conn,
                           "SELECT wsg.* FROM whse_basemapping.fwa_watershed_groups_poly wsg
          INNER JOIN working.ufn t
          ON ST_Intersects(t.geometry,wsg.geom)")

ldn_wsg <- DBI::dbGetQuery(conn,
                           "SELECT wsg.* FROM whse_basemapping.fwa_watershed_groups_poly wsg
          INNER JOIN working.ldn t
          ON ST_Intersects(t.geometry,wsg.geom)")

DBI::dbDisconnect(conn = conn)

wsg <- bind_rows(ufn_wsg,ldn_wsg) %>%
  distinct(watershed_group_code) %>%
  # manual review shows that KNIG and OWIK have really small areas
  filter(!watershed_group_code %in% c('KNIG', 'OWIK')) %>%
  arrange(watershed_group_code)

# make a list
wsg_l <- wsg %>%
  pull(watershed_group_code)

# this is handy for copying and pasting into qgis
paste(shQuote(wsg_l), collapse=", ")

# import the csv from bcfishpass, join with FN wshd groups, get unique, add `cw` and burn back out
bcfp <- readr::read_csv('../bcfishpass/parameters/parameters_newgraph/watersheds.csv')

wsg_all <- bind_rows(bcfp, wsg) %>%
  # going to add the ELKR and KOTL
  tibble::add_row(watershed_group_code = 'ELKR') %>%
  tibble::add_row(watershed_group_code = 'KOTL') %>%
  distinct(watershed_group_code, .keep_all = T) %>%
  mutate(model = 'cw') %>%
  arrange(watershed_group_code)


wsg_all %>%
  write_csv('../bcfishpass/parameters/watersheds.csv')


# here we can hack together a test
wsg_all %>%
  slice(1) %>%
  write_csv('../bcfishpass/parameters/watersheds.csv')
