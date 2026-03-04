workflow snapshot_parameters {
    main:
    // Store workflow configurations to meta folder
    def paramsFile = "${params.out_dir}/params.json"
    // Write parameters as pretty-printed JSON and create directory
    new File(paramsFile).parentFile.mkdirs()
    new File(paramsFile).withWriter {writer -> 
    writer << groovy.json.JsonOutput.prettyPrint(groovy.json.JsonOutput.toJson(params))
    }

    // Store configurations if run_type = "file"
    if (params.run_type == "file") {
        def configFile = "${params.out_dir}/config.csv"
        new File(configFile).withWriter {configWriter ->
        configWriter << new File(params.diff_net_analysis.path_config).text
        }
    }   

}