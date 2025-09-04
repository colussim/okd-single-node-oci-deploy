NS=$(oci os ns get --query 'data' --raw-output)             
COMPARTMENT_OCID="ocid1.compartment.oc1..xxxxx" 
BUCKET=okd-images              
REGION=us-ashburn-1      
BIMAGE= okd-custom-image_x86.vmdk  

PAR_PATH=$(oci os preauth-request create --bucket-name "$BUCKET" --name read-scos \      
--access-type ObjectRead --object-name  "BIMAGE " \                    
--time-expires "2026-12-31T23:59:59Z" --query 'data."access-uri" --raw-output)   


oci compute image import from-object-uri \                             
--compartment-id "$COMPARTMENT_OCID" \                                 
--display-name "okd-custom-image_x86-oraclecloud-vmdk" \               
--launch-mode PARAVIRTUALIZED \                                        
--operating-system "Linux" --operating-system-version "9" \           
 --source-image-type VMDK --uri "https://objectstorage.$REGION.oraclecloud.com${PAR_PATH}"
