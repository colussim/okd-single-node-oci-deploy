COMPARTMENT_OCID="ocid1.compartment.oc1..xxxx"                         
BUCKET=okd-images                                                      
REGION=us-ashburn-1                                                    
FILE=/data02/scos-okd-sno/okd-sno.vmdk      
                                                                                                  
oci os object put --bucket-name "$BUCKET" --file "$FILE" --name okd-custom-image_x86.vmdk   
