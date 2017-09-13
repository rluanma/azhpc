required_envvars nnodes_list ppn_list storageAccountName storageContainerName storageBenchmarkPath storageBenchmarkName storageSasKey

function run_benchmark {

    execute "install_openfoam" ssh hpcuser@${public_ip} azhpc/install/install_openfoam.sh
    execute "download_case" ssh hpcuser@${public_ip} "cd /mnt/resource/scratch && wget https://$storageAccountName.blob.core.windows.net/$storageContainerName/$storageBenchmarkPath/$storageBenchmarkName.tar -O - | tar xvf"

    for NNODES in $nnodes_list; do
        for PPN in $ppn_list; do
            execute "create_case_${NNODES}x${PPN}" ssh hpcuser@${public_ip} "ssh \$(cat bin/hostlist) 'cd /mnt/resource/scratch && ./$storageBenchmarkName/create_case.sh $NNODES $PPN'"
            decomposedCase=${storageBenchmarkName}_${NNODES}x${PPN}
            execute "copy_$decomposedCase" scp hpcuser@${public_ip}:/mnt/resource/scratch/$decomposedCase.tar .
            execute "upload_$decomposedCase" az storage blob upload \
                --account-name $storageAccountName \
                --container-name $storageContainerName \
                --file $decomposedCase.tar \
                --name $storageBenchmarkPath/$decomposedCase.tar \
                --sas "$storageSasKey"
            execute "delete_$decomposedCase_dir" rm -rf $decomposedCase
            execute "delete_$decomposedCase_tarfile" rm $decomposedCase.tar
        done
    done

}
