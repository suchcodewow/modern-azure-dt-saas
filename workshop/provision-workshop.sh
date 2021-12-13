#!/bin/bash

source ./lib/_provision-scripts.lib

setup_workshop_config()
{
    # this scripts will add workshop config like tags, dashboard, MZ
    # need to change directories so that the generated monaco files
    # are in the right folder

    cd ../workshop-config
    ./setup-workshop-config.sh
    ./setup-workshop-config.sh k8
    ./setup-workshop-config.sh dashboard $DASHBOARD_OWNER_EMAIL
    cd ../provision-scripts
}

createhost active-gate
createhost eval_monolith    
create_aks_cluster
<<<<<<< HEAD
#workshop config above
=======
#workshop config above

>>>>>>> 9e7241cb2f4bfda3da35af05e36f268855b8a442
