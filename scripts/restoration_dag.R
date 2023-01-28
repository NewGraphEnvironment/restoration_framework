library(ggdag)
library(ggplot2)
theme_set(theme_dag())


# this is a good resource for the HARP model https://www.fisheries.noaa.gov/resource/tool-app/habitat-assessment-and-restoration-planning-harp-model
# northwest fisheries science centre https://www.fisheries.noaa.gov/about/northwest-fisheries-science-center

# columbia basin historical habitat project https://www.fisheries.noaa.gov/resource/data/columbia-basin-historical-ecology-project-data

ggdag(dagify(cholesterol ~ smoking + weight))
