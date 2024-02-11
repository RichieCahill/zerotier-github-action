set -euo pipefail
IFS=$'\n\t'

echo "⏁  Installing ZeroTier"

case $(uname -s) in
  MINGW64_NT?*)
    pwsh "${{ github.action_path }}/util/install.ps1"
    ztcli="/c/Program Files (x86)/ZeroTier/One/zerotier-cli.bat"
    member_id=$("${ztcli}" info | awk '{ print $3 }')
    ;;
  *)
    . ${{ github.action_path }}/util/install.sh &>/dev/null
    member_id=$(sudo zerotier-cli info | awk '{ print $3 }')
  ;;
esac

echo "⏁  Authorizing Runner to ZeroTier network"
MAX_RETRIES=10
RETRY_COUNT=0

while ! curl -s -X POST \
-H "Authorization: token ${{ inputs.auth_token }}" \
-H "Content-Type: application/json" \
-d '{"name":"Zerotier GitHub Member '"${GITHUB_SHA::7}"'", "description": "Member created by '"${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"'", "config":{"authorized":true}}' \
"${{ inputs.api_url }}/network/${{ inputs.network_id }}/member/${member_id}" | grep '"authorized":true'; 
do 
    RETRY_COUNT=$((RETRY_COUNT+1))
    
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "Reached maximum number of retries ($MAX_RETRIES). Exiting..."
        exit 1
    fi

    echo "Authorization failed. Retrying in 2 seconds... (Attempt $RETRY_COUNT of $MAX_RETRIES)"
    sleep 2
done

echo "Member authorized successfully."
echo "⏁  Joining ZeroTier Network ID: ${{ inputs.network_id }}"
case $(uname -s) in
  MINGW64_NT?*)
    "${ztcli}" join ${{ inputs.network_id }}
    while ! "${ztcli}" listnetworks | grep ${{ inputs.network_id }} | grep OK ; do sleep 0.5 ; done
    ;;
  *)
    sudo zerotier-cli join ${{ inputs.network_id }}
    while ! sudo zerotier-cli listnetworks | grep ${{ inputs.network_id }} | grep OK ; do sleep 0.5 ; done
    ;;
esac
