# Before we can load headers we need some paths defined.  They
# may be provided by a system environment variable or just
# having already been set in the workspace
if( !exists( "EMISSPROC_DIR" ) ){
    if( Sys.getenv( "EMISSIONSPROC" ) != "" ){
        EMISSPROC_DIR <- Sys.getenv( "EMISSIONSPROC" )
    } else {
        stop("Could not determine location of emissions data system. Please set the R var EMISSPROC_DIR to the appropriate location")
    }
}

# Universal header file - provides logging, file support, etc.
source(paste(EMISSPROC_DIR,"/../_common/headers/GCAM_header.R",sep=""))
source(paste(EMISSPROC_DIR,"/../_common/headers/EMISSIONS_header.R",sep=""))
logstart( "L212.unmgd_nonco2.R" )
adddep(paste(EMISSPROC_DIR,"/../_common/headers/GCAM_header.R",sep=""))
adddep(paste(EMISSPROC_DIR,"/../_common/headers/EMISSIONS_header.R",sep=""))
printlog( "Historical emissions from unmanaged land" )

# -----------------------------------------------------------------------------
# 1. Read files

sourcedata( "COMMON_ASSUMPTIONS", "A_common_data", extension = ".R" )
sourcedata( "COMMON_ASSUMPTIONS", "level2_data_names", extension = ".R" )
sourcedata( "MODELTIME_ASSUMPTIONS", "A_modeltime_data", extension = ".R" )
sourcedata( "AGLU_ASSUMPTIONS", "A_aglu_data", extension = ".R" )
sourcedata( "EMISSIONS_ASSUMPTIONS", "A_emissions_data", extension = ".R" )
GCAM_region_names <- readdata( "COMMON_MAPPINGS", "GCAM_region_names")
A_regions <- readdata( "EMISSIONS_ASSUMPTIONS", "A_regions" )
L125.R_AEZ_nonexist <- readdata( "AGLU_LEVEL1_DATA", "L125.R_AEZ_nonexist" )
L124.nonco2_tg_R_grass_Y_AEZ <- readdata( "EMISSIONS_LEVEL1_DATA", "L124.nonco2_tg_R_grass_Y_AEZ" )
L124.nonco2_tg_R_forest_Y_AEZ <- readdata( "EMISSIONS_LEVEL1_DATA", "L124.nonco2_tg_R_forest_Y_AEZ" )
L125.bcoc_tgbkm2_R_grass_2000 <- readdata( "EMISSIONS_LEVEL1_DATA", "L125.bcoc_tgbkm2_R_grass_2000" )
L125.bcoc_tgbkm2_R_forest_2000 <- readdata( "EMISSIONS_LEVEL1_DATA", "L125.bcoc_tgbkm2_R_forest_2000" )
L124.nonco2_tgbm2_grass_fy.melt <- readdata( "EMISSIONS_LEVEL1_DATA", "L124.nonco2_tgbm2_grass_fy.melt" )
L124.nonco2_tgbm2_forest_fy.melt <- readdata( "EMISSIONS_LEVEL1_DATA", "L124.nonco2_tgbm2_forest_fy.melt" )

# -----------------------------------------------------------------------------
# 2. Build tables for CSVs
#Unmanaged land sector info
printlog( "L212.Sector: Sector info for unmanaged land technology" )
L212.Sector <- GCAM_region_names[ names( GCAM_region_names ) == "region" ]
L212.Sector$AgSupplySector <- "UnmanagedLand"
L212.Sector$output.unit <- "none"
L212.Sector$input.unit <- "thous km2"
L212.Sector$price.unit <- "none"
L212.Sector$calPrice <- -1
L212.Sector$market <- L212.Sector$region
L212.Sector$logit.year.fillout <- min( model_base_years )
L212.Sector$logit.exponent <- -3

printlog( "L212.ItemName: Land item to relate emissions to" )
L212.LandItem <- L212.Sector[ names( L212.Sector ) %in% c( "region", "AgSupplySector" )]
L212.LandItem <- repeat_and_add_vector( L212.LandItem, "AgSupplySubsector", c( "ForestFires", "GrasslandFires") )
L212.LandItem$itemName[ L212.LandItem$AgSupplySubsector == "ForestFires" ] <- "UnmanagedForest" 
L212.LandItem$itemName[ L212.LandItem$AgSupplySubsector == "GrasslandFires" ] <- "Grassland" 
L212.LandItem <- repeat_and_add_vector( L212.LandItem, "AEZ", AEZs )
L212.LandItem$AgSupplySubsector <- paste( L212.LandItem$AgSupplySubsector, L212.LandItem$AEZ, sep="" )
L212.LandItem$UnmanagedLandTechnology <- L212.LandItem$AgSupplySubsector
L212.LandItem$itemName <- paste( L212.LandItem$itemName, L212.LandItem$AEZ, sep="" )
L212.LandItem <- repeat_and_add_vector( L212.LandItem, "year", model_base_years )
L212.LandItem <- L212.LandItem[ c( names_UnmgdTech, "year", "itemName" )]

#Grassland emissions
printlog( "L212.GrassEmissions: Grassland fire emissions in all regions" )
#Interpolate and add region name
L212.GRASS <- L124.nonco2_tg_R_grass_Y_AEZ[ names( L124.nonco2_tg_R_grass_Y_AEZ ) %!in% c( "X2009", "X2010") ]

#Note: interpolate takes ages, so I'm not using interpolate_and_melt
L212.GRASS <- melt( L212.GRASS, id.vars = grep( "X[0-9]{4}", names( L212.GRASS ), invert = T ) )
L212.GRASS <- na.omit( L212.GRASS )
L212.GRASS$year <- as.numeric( substr( L212.GRASS$variable, 2, 5 ) )
L212.GRASS <- subset( L212.GRASS, L212.GRASS$year %in% emiss_model_base_years )
L212.GRASS <- add_region_name( L212.GRASS )

#Add subsector and tech names
L212.GRASS$AgSupplySector <- "UnmanagedLand"
L212.GRASS$AgSupplySubsector <- paste( "GrasslandFires", L212.GRASS$AEZ, sep="" )
L212.GRASS$UnmanagedLandTechnology <- paste( "GrasslandFires", L212.GRASS$AEZ, sep="" )

#Format for csv file
L212.GRASSEmissions <- L212.GRASS[ c( names_UnmgdTech, "year", "Non.CO2" ) ]
L212.GRASSEmissions$input.emissions <- L212.GRASS$value
L212.GRASSEmissions <- na.omit( L212.GRASSEmissions )

#Grassland emissions factors for BC/OC
printlog( "L212.GrassEmissions: Grassland fire emissions factors for BC/OC in all regions" )
L212.GRASSEF_BCOC <- L125.bcoc_tgbkm2_R_grass_2000
L212.GRASSEF_BCOC <- na.omit( L212.GRASSEF_BCOC )
names( L212.GRASSEF_BCOC )[ names( L212.GRASSEF_BCOC ) == "X2000" ] <- "value"
L212.GRASSEF_BCOC <- repeat_and_add_vector( L212.GRASSEF_BCOC, "year", emiss_model_base_years )
L212.GRASSEF_BCOC <- add_region_name( L212.GRASSEF_BCOC )
L212.GRASSEF_BCOC <- repeat_and_add_vector( L212.GRASSEF_BCOC, "AEZ", AEZs )

#Add subsector and tech names
L212.GRASSEF_BCOC$AgSupplySector <- "UnmanagedLand"
L212.GRASSEF_BCOC$AgSupplySubsector <- paste( "GrasslandFires", L212.GRASSEF_BCOC$AEZ, sep="" )
L212.GRASSEF_BCOC$UnmanagedLandTechnology <- paste( "GrasslandFires", L212.GRASSEF_BCOC$AEZ, sep="" )

#Format for csv file
L212.GRASSEmissionsFactors_BCOC <- L212.GRASSEF_BCOC[ c( names_UnmgdTech, "year", "Non.CO2" ) ]
L212.GRASSEmissionsFactors_BCOC$emiss.coef <- L212.GRASSEF_BCOC$value
L212.GRASSEmissionsFactors_BCOC <- na.omit( L212.GRASSEmissionsFactors_BCOC )

#Forest fire emissions
printlog( "L212.ForestEmissions: Forest fire emissions in all regions" )
#Interpolate and add region name
L212.FOREST <- L124.nonco2_tg_R_forest_Y_AEZ[ names( L124.nonco2_tg_R_forest_Y_AEZ ) %!in% c( "X2009", "X2010") ]

#Note: interpolate takes ages, so I'm not using interpolate_and_melt
L212.FOREST <- melt( L212.FOREST, id.vars = grep( "X[0-9]{4}", names( L212.FOREST ), invert = T ) )
L212.FOREST <- na.omit( L212.FOREST )
L212.FOREST$year <- as.numeric( substr( L212.FOREST$variable, 2, 5 ) )
L212.FOREST <- subset( L212.FOREST, L212.FOREST$year %in% emiss_model_base_years )
L212.FOREST <- add_region_name( L212.FOREST )

#Add subsector and tech names
L212.FOREST$AgSupplySector <- "UnmanagedLand"
L212.FOREST$AgSupplySubsector <- paste( "ForestFires", L212.FOREST$AEZ, sep="" )
L212.FOREST$UnmanagedLandTechnology <- paste( "ForestFires", L212.FOREST$AEZ, sep="" )

#Format for csv file
L212.FORESTEmissions <- L212.FOREST[ c( names_UnmgdTech, "year", "Non.CO2" ) ]
L212.FORESTEmissions$input.emissions <- L212.FOREST$value
L212.FORESTEmissions <- na.omit( L212.FORESTEmissions )

#Forest fire emissions factors for BC/OC
printlog( "L212.ForestEmissions: Forest fire emissions factors for BC/OC in all regions" )
#Interpolate and add region name
L212.FORESTEF_BCOC <- L125.bcoc_tgbkm2_R_forest_2000
L212.FORESTEF_BCOC <- na.omit( L212.FORESTEF_BCOC )
names( L212.FORESTEF_BCOC )[ names( L212.FORESTEF_BCOC ) == "X2000" ] <- "value"
L212.FORESTEF_BCOC <- repeat_and_add_vector( L212.FORESTEF_BCOC, "year", emiss_model_base_years )
L212.FORESTEF_BCOC <- add_region_name( L212.FORESTEF_BCOC )
L212.FORESTEF_BCOC <- repeat_and_add_vector( L212.FORESTEF_BCOC, "AEZ", AEZs )

#Add subsector and tech names
L212.FORESTEF_BCOC$AgSupplySector <- "UnmanagedLand"
L212.FORESTEF_BCOC$AgSupplySubsector <- paste( "ForestFires", L212.FORESTEF_BCOC$AEZ, sep="" )
L212.FORESTEF_BCOC$UnmanagedLandTechnology <- paste( "ForestFires", L212.FORESTEF_BCOC$AEZ, sep="" )

#Format for csv file
L212.FORESTEmissionsFactors_BCOC <- L212.FORESTEF_BCOC[ c( names_UnmgdTech, "year", "Non.CO2" ) ]
L212.FORESTEmissionsFactors_BCOC$emiss.coef <- L212.FORESTEF_BCOC$value
L212.FORESTEmissionsFactors_BCOC <- na.omit( L212.FORESTEmissionsFactors_BCOC )

#Forest fire emissions factors for pollutant gases in future years
printlog( "L212.ForestEmissions: Forest fire emissions factors for pollutant gases in future years" )
#Interpolate and add region name
L212.FORESTEF <- L124.nonco2_tgbm2_forest_fy.melt
L212.FORESTEF <- repeat_and_add_vector( L212.FORESTEF, "region", GCAM_region_names$region )
L212.FORESTEF$year <- 2010
L212.FORESTEF <- repeat_and_add_vector( L212.FORESTEF, "AEZ", AEZs )

#Add subsector and tech names
L212.FORESTEF$AgSupplySector <- "UnmanagedLand"
L212.FORESTEF$AgSupplySubsector <- paste( "ForestFires", L212.FORESTEF$AEZ, sep="" )
L212.FORESTEF$UnmanagedLandTechnology <- paste( "ForestFires", L212.FORESTEF$AEZ, sep="" )

#Format for csv file
L212.FORESTEmissionsFactors <- L212.FORESTEF[ c( names_UnmgdTech, "year", "Non.CO2" ) ]
L212.FORESTEmissionsFactors$emiss.coef <- L212.FORESTEF$em_fact
L212.FORESTEmissionsFactors <- na.omit( L212.FORESTEmissionsFactors )

#Grassland fire emissions factors for pollutant gases in future years
printlog( "L212.GrassEmissions: Grassland fire emissions factors for pollutant gases in future years" )
#Interpolate and add region name
L212.GRASSEF <- L124.nonco2_tgbm2_grass_fy.melt
L212.GRASSEF <- repeat_and_add_vector( L212.GRASSEF, "region", GCAM_region_names$region )
L212.GRASSEF$year <- 2010
L212.GRASSEF <- repeat_and_add_vector( L212.GRASSEF, "AEZ", AEZs )

#Add subsector and tech names
L212.GRASSEF$AgSupplySector <- "UnmanagedLand"
L212.GRASSEF$AgSupplySubsector <- paste( "GrasslandFires", L212.GRASSEF$AEZ, sep="" )
L212.GRASSEF$UnmanagedLandTechnology <- paste( "GrasslandFires", L212.GRASSEF$AEZ, sep="" )

#Format for csv file
L212.GRASSEmissionsFactors <- L212.GRASSEF[ c( names_UnmgdTech, "year", "Non.CO2" ) ]
L212.GRASSEmissionsFactors$emiss.coef <- L212.GRASSEF$em_fact
L212.GRASSEmissionsFactors <- na.omit( L212.GRASSEmissionsFactors )

printlog( "Removing non-existent regions and AEZs from all tables")
L212.Sector <- subset( L212.Sector, !region %in% no_aglu_regions )
L212.GRASSEmissions <- remove_AEZ_nonexist( L212.GRASSEmissions )
L212.GRASSEmissionsFactors <- remove_AEZ_nonexist( L212.GRASSEmissionsFactors )
L212.GRASSEmissionsFactors_BCOC <- remove_AEZ_nonexist( L212.GRASSEmissionsFactors_BCOC )
L212.FORESTEmissions <- remove_AEZ_nonexist( L212.FORESTEmissions )
L212.FORESTEmissionsFactors <- remove_AEZ_nonexist( L212.FORESTEmissionsFactors )
L212.FORESTEmissionsFactors_BCOC <- remove_AEZ_nonexist( L212.FORESTEmissionsFactors_BCOC )
L212.LandItem <- remove_AEZ_nonexist( L212.LandItem )

printlog( "Rename to regional SO2" )
L212.GRASSEmissions <- rename_SO2( L212.GRASSEmissions, A_regions, FALSE )
L212.GRASSEmissionsFactors <- rename_SO2( L212.GRASSEmissionsFactors, A_regions, FALSE )
L212.FORESTEmissions <- rename_SO2( L212.FORESTEmissions, A_regions, FALSE )
L212.FORESTEmissionsFactors <- rename_SO2( L212.FORESTEmissionsFactors, A_regions, FALSE )

# Add logit tags to avoid errors
L212.SectorLogitType <- L212.Sector
L212.SectorLogitType$logit.type <- NA
L212.SectorLogitTables <- get_logit_fn_tables( L212.SectorLogitType, names_AgSupplySectorLogitType,
    base.header="AgSupplySector_", include.equiv.table=T, write.all.regions=F )
# We do not actually care about the logit here but we need a value to avoid errors
L212.AgSupplySubsector <- L212.LandItem[, names_AgSupplySubsector ]
L212.AgSupplySubsector$logit.year.fillout <- min( model_base_years )
L212.AgSupplySubsector$logit.exponent <- -3
L212.SubsectorLogitType <- L212.LandItem
L212.SubsectorLogitType$logit.type <- NA
L212.SubsectorLogitTables <- get_logit_fn_tables( L212.SubsectorLogitType, names_AgSupplySubsectorLogitType,
    base.header="AgSupplySubsector_", include.equiv.table=F, write.all.regions=F )

# -----------------------------------------------------------------------------
# 3. Write all csvs as tables, and paste csv filenames into a single batch XML file
for( curr_table in names ( L212.SectorLogitTables ) ) {
write_mi_data( L212.SectorLogitTables[[ curr_table ]]$data, L212.SectorLogitTables[[ curr_table ]]$header,
    "EMISSIONS_LEVEL2_DATA", paste0("L212.", L212.SectorLogitTables[[ curr_table ]]$header ), "EMISSIONS_XML_BATCH",
    "batch_all_unmgd_emissions.xml" )
}
write_mi_data( L212.Sector, "AgSupplySector", "EMISSIONS_LEVEL2_DATA", "L212.Sector", "EMISSIONS_XML_BATCH", "batch_all_unmgd_emissions.xml" ) 
for( curr_table in names ( L212.SubsectorLogitTables ) ) {
write_mi_data( L212.SubsectorLogitTables[[ curr_table ]]$data, L212.SubsectorLogitTables[[ curr_table ]]$header,
    "EMISSIONS_LEVEL2_DATA", paste0("L212.", L212.SubsectorLogitTables[[ curr_table ]]$header ), "EMISSIONS_XML_BATCH",
    "batch_all_unmgd_emissions.xml" )
}
write_mi_data( L212.AgSupplySubsector, "AgSupplySubsector", "EMISSIONS_LEVEL2_DATA", "L212.AgSupplySubsector", "EMISSIONS_XML_BATCH", "batch_all_unmgd_emissions.xml" ) 
write_mi_data( L212.LandItem, "ItemNameUnmgd", "EMISSIONS_LEVEL2_DATA", "L212.LandItem", "EMISSIONS_XML_BATCH", "batch_all_unmgd_emissions.xml" ) 
write_mi_data( L212.GRASSEmissions, "InputEmissionsUnmgd", "EMISSIONS_LEVEL2_DATA", "L212.GRASSEmissions", "EMISSIONS_XML_BATCH", "batch_all_unmgd_emissions.xml" ) 
write_mi_data( L212.FORESTEmissions, "InputEmissionsUnmgd", "EMISSIONS_LEVEL2_DATA", "L212.FORESTEmissions", "EMISSIONS_XML_BATCH", "batch_all_unmgd_emissions.xml" ) 
write_mi_data( L212.GRASSEmissionsFactors_BCOC, "InputEmFactUnmgd", "EMISSIONS_LEVEL2_DATA", "L212.GRASSEmissionsFactors_BCOC", "EMISSIONS_XML_BATCH", "batch_all_unmgd_emissions.xml" ) 
write_mi_data( L212.FORESTEmissionsFactors_BCOC, "InputEmFactUnmgd", "EMISSIONS_LEVEL2_DATA", "L212.FORESTEmissionsFactors_BCOC", "EMISSIONS_XML_BATCH", "batch_all_unmgd_emissions.xml" ) 
write_mi_data( L212.GRASSEmissionsFactors, "InputEmFactUnmgd", "EMISSIONS_LEVEL2_DATA", "L212.GRASSEmissionsFactors", "EMISSIONS_XML_BATCH", "batch_all_unmgd_emissions.xml" ) 
write_mi_data( L212.FORESTEmissionsFactors, "InputEmFactUnmgd", "EMISSIONS_LEVEL2_DATA", "L212.FORESTEmissionsFactors", "EMISSIONS_XML_BATCH", "batch_all_unmgd_emissions.xml" ) 

insert_file_into_batchxml( "EMISSIONS_XML_BATCH", "batch_all_unmgd_emissions.xml", "EMISSIONS_XML_FINAL", "all_unmgd_emissions.xml", "", xml_tag="outFile" )

logstop()
