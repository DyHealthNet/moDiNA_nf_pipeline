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

    // Copy input data files if data_type = "real"
    if (params.data_type == "real") {
        java.nio.file.Files.copy(new File(params.real_world_data.path_context_1).toPath(), new File("${params.out_dir}/${params.name_context_1}_data.csv").toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
        java.nio.file.Files.copy(new File(params.real_world_data.path_context_2).toPath(), new File("${params.out_dir}/${params.name_context_2}_data.csv").toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
        java.nio.file.Files.copy(new File(params.real_world_data.path_meta).toPath(), new File("${params.out_dir}/meta.csv").toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
    }

}