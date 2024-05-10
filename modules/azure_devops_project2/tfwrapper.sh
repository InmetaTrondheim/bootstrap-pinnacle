#!/bin/bash
# Wrapper script to run 'tofu init' automatically before 'tofu plan' or 'tofu apply'

# Check if the .tofu directory does not exist or is empty
if [ ! -d ".tofu" ] || [ -z "$(ls -A .tofu)" ]; then
  echo "Initializing tofu..."
  tofu init
fi


# Execute the appropriate tofu command
case "$1" in
  plan)
    tofu plan "${@:2}"  # Passes along any additional arguments
    ;;
  test)
    tofu test "${@:2}"  # Passes along any additional arguments
    ;;
  apply)
    tofu apply -auto-approve "${@:2}"  # Automatically approve and pass any additional arguments
    ;;
  *)
    echo "Invalid command. Use 'plan', 'test' or 'apply'."
    ;;
esac

