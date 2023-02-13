set +x

SESSION_ID=$(cat "${WORKSPACE}"/session_id)

duffy client retire-session "${SESSION_ID}" > /dev/null
