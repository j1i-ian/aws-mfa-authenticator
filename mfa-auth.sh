
echo -n "Set MFA profile name (default mfa): "
read MFA_PROFILE_NAME

if [ -z "$MFA_PROFILE_NAME" ]; then
    MFA_PROFILE_NAME=mfa
fi

# 36 hours
SESSION_TIME=129600
# Seoul
DEFAULT_REGION=ap-northeast-2

function install_check() {
    which $1 > /dev/null;

    if [[ $? -ne 0 ]]; then
        echo "Please install $1."
        exit 1;
    else
        echo "$1 install is checked."
    fi
}

# check aws cli
install_check "aws"

# check jq cli
install_check "jq"

aws configure set --profile $MFA_PROFILE_NAME output json

CHECK_SESSION=$(aws ssm describe-sessions --state History 2> /dev/null)
MFA_DEVICE_ARN=$(aws configure get --profile $MFA_PROFILE_NAME mfa_serial)

if [ $CHECK_SESSION ] && [ -z $MFA_DEVICE_ARN ]; then
    # session is aliving
    AWS_USER_ID=$(aws sts get-caller-identity | jq -r ".UserId")
    MFA_DEVICE_ARN=$(aws iam list-virtual-mfa-devices | jq -r '.VirtualMFADevices[] | select(.User.UserId == "'$AWS_USER_ID'") | .SerialNumber')
elif [ -z $MFA_DEVICE_ARN ]; then
    echo -n "Please input mfa serial:"
    read MFA_DEVICE_ARN
fi

aws configure set --profile $MFA_PROFILE_NAME mfa_serial $MFA_DEVICE_ARN

echo "Detected ARN: "$MFA_DEVICE_ARN

echo -n "Input OTP:"
read TOKEN_CODE

MFA_PROFILE=$(aws sts get-session-token --serial-number $MFA_DEVICE_ARN --token-code $TOKEN_CODE --duration-seconds $SESSION_TIME)

echo $MFA_PROFILE | jq
MFA_PROFILE_ACCESS_KEY=$(echo $MFA_PROFILE | jq -r ".Credentials.AccessKeyId")
MFA_PROFILE_SECRET_ACCESS_KEY=$(echo $MFA_PROFILE | jq -r ".Credentials.SecretAccessKey")
MFA_PROFILE_SESSION_TOKEN=$(echo $MFA_PROFILE | jq -r ".Credentials.SessionToken")

aws configure set --profile $MFA_PROFILE_NAME mfa_serial $MFA_DEVICE_ARN
aws configure set --profile $MFA_PROFILE_NAME region $DEFAULT_REGION
aws configure set --profile $MFA_PROFILE_NAME aws_access_key_id $MFA_PROFILE_ACCESS_KEY
aws configure set --profile $MFA_PROFILE_NAME aws_secret_access_key $MFA_PROFILE_SECRET_ACCESS_KEY
aws configure set --profile $MFA_PROFILE_NAME aws_session_token $MFA_PROFILE_SESSION_TOKEN
aws configure set --profile $MFA_PROFILE_NAME output json
