#!/bin/bash
#ACCESS TO AWS ACCOUT
echo "Enter your ACCES_KEY from AWS account: "
read ACCES_KEY
Alen=$(expr length "$ACCES_KEY")

while [ $Alen -ne "20" ]
do
    echo "Enter right ACCESS_KEY: "
    read ACCES_KEY
    Alen=$(expr length "$ACCES_KEY")
done

echo "Enter your SECRET_KEY from AWS account: "
read SECRET_KEY
Slen=$(expr length "$SECRET_KEY")
while [ $Slen -ne "40" ]
do
    echo "Enter correct SECRET_KEY: "
    read SECRET_KEY
    Slen=$(expr length "$SECRET_KEY")
done
#CHOOSE REGION
regions=(us-east-2 us-east-1 us-west-1 us-west-2 af-south-1 ap-east-1 ap-south-2 ap-southeast-3 ap-southeast-4 ap-south-1 ap-northeast-3 ap-northeast-2 ap-southeast-1 ap-southeast-2
ap-northeast-1 ca-central-1 eu-central-1 eu-west-1 eu-west-2 eu-south-1 eu-west-3 eu-south-2 eu-north-1 eu-central-2 me-south-1 me-central-1 sa-east-1)
echo "Do you wanna to stay at default region: (yes/no only) "
read ANSWEAR
while [ $ANSWEAR != "yes" ] && [ $ANSWEAR != "no" ]
do
    echo "Do you wanna to stay at default region (${regions[0]}): (yes/no only) "
    read ANSWEAR
done
chose_region=None
if [ "$ANSWEAR" == "yes" ]
then
    echo "Okay, stay here"
    chose_region=${regions[0]}
elif [ "$ANSWEAR" == "no" ]
then
    echo "Okay, AWS have next regions:
    1. us-east-2
    2. us-east-1
    3. us-west-1
    4. us-west-2
    5. af-south-1
    6. ap-east-1
    7. ap-south-2
    8. ap-southeast-3
    9. ap-southeast-4
    10. ap-south-1
    11. ap-northeast-3
    12. ap-northeast-2
    13. ap-southeast-1
    14. ap-southeast-2
    15. ap-northeast-1
    16. ca-central-1
    17. eu-central-1
    18. eu-west-1
    19. eu-west-2
    20. eu-south-1
    21. eu-west-3
    22. eu-south-2
    23. eu-north-1
    24. eu-central-2
    25. me-south-1
    26. me-central-1
    27. sa-east-1
    Please choose index of interested region: 
    "
    read INDEX
    while [ $INDEX -gt 27 ] || [ $INDEX -lt 1 ]
    do
        echo "Okay, one more time, AWS have next regions:
        1. us-east-2
        2. us-east-1
        3. us-west-1
        4. us-west-2
        5. af-south-1
        6. ap-east-1
        7. ap-south-2
        8. ap-southeast-3
        9. ap-southeast-4
        10. ap-south-1
        11. ap-northeast-3
        12. ap-northeast-2
        13. ap-southeast-1
        14. ap-southeast-2
        15. ap-northeast-1
        16. ca-central-1
        17. eu-central-1
        18. eu-west-1
        19. eu-west-2
        20. eu-south-1
        21. eu-west-3
        22. eu-south-2
        23. eu-north-1
        24. eu-central-2
        25. me-south-1
        26. me-central-1
        27. sa-east-1
        Please choose index of interested region: 
        "
        read INDEX
    done
    chose_region=${regions[$INDEX-1]}
    echo "Okay, you choose $chose_region"
fi

echo "regions:  $chose_region" >> ./ansible/inventory/aws_ec2.yaml
export AWS_ACCESS_KEY_ID=$ACCES_KEY
export AWS_SECRET_ACCESS_KEY=$SECRET_KEY
export AWS_DEFAULT_REGION=$chose_region
#Work with terraform remote states
cd terraform/
terraform init
terraform apply
echo "Now will be up IAC in remote states, wait 10 sec to remote states    "
sleep 10
echo "
terraform {
  backend \"s3\" {
    bucket = \"bakur-tfstate-bucket\"
    key = \"dev/network/terraform.tfstate\"
    dynamodb_table = \"terraform-state-locking\"
    encrypt = true
  }

}
" >> ./terraform/main.tf
terraform init
terraform apply
echo "Now, we wait again)"
sleep 10
cd ../ansible/
ansible-playbook rolebook.yaml

echo "Okay, at now, we install docker on our servers and download image, and make containers"
echo "And we use dynamic inventory) but not at now, where i write this text"
