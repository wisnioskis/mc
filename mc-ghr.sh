#!/bin/bash

# Function to check if the script is running as root
function check_root {
    if [ "$(id -u)" -ne "0" ]; then
        echo "This script requires root privileges. Elevating privileges..."
        echo  # Add a newline for better readability
        exec sudo "$0" "$@"
    fi
}

# Function to display script usage/help
function display_help {
    echo "Did you know: this script can be run with command-line arguments?"
    echo
    echo "Usage: mc [-n] [-r] [-rv] [-o] [-b] [-i interface]"
    echo
    echo "Options:"
    echo "  -n                Set a new MAC address (requires -i interface)"
    echo "  -r                Set a random MAC address (requires -i interface)"
    echo "  -rv               Set a random vendor MAC address (requires -i interface)"
    echo "  -o                Reset MAC address to permanent hardware address (requires -i interface)"
    echo "  -b                Set MAC address as a burned-in address (only with -r)"
    echo "  -i interface      Specify the network interface to operate on"
    echo "  -h, --help        Display this help message"
}

# Function to get the interface names and their states
function get_interfaces {
    ip link show | awk -F': ' '/^[0-9]+:/{print $2}'
}

# Function to get the state of a given interface
function get_interface_state {
    local iface="$1"
    ip link show "$iface" | grep -Eo 'state [^ ]+' | awk '{print $2}'
}

# Function to list interfaces with numbers
function list_interfaces {
    echo "Available interfaces:"
    local interfaces=($(get_interfaces))
    local index=1
    for iface in "${interfaces[@]}"; do
        local state=$(get_interface_state "$iface")
        state=${state:-UNKNOWN}  # Default to UNKNOWN if state is not detected
        echo "$index: $iface ($state)"
        index=$((index + 1))
    done
}

# Function to select an interface by number
function select_interface {
    local interfaces=($(get_interfaces))
    list_interfaces
    read -p "Enter the number of the interface you want to use: " iface_num
    if [[ $iface_num -ge 1 && $iface_num -le ${#interfaces[@]} ]]; then
        interface="${interfaces[$((iface_num - 1))]}"
        echo "Selected interface: $interface"
        return 0
    else
        echo "Invalid selection."
        return 1
    fi
}

# Function to list cool MAC addresses
function list_cool_macs {
    echo "Cool MAC addresses:"
    local macs=(
        "DE:AD:BE:EF:DE:AD|Dead Beef"
        "DE:C0:DE:C0:DE:00|Decode"
        "C0:FF:EE:CA:FE:00|Coffee Cafe"
        "BA:DD:C0:FF:EE:00|Bad Coffee"
        "BA:DB:AD:CA:FE:00|Bad, Bad Cafe"
        "CA:FE:BA:BE:00:01|Cafe Babe"
        "FA:CE:B0:0C:00:01|Facebook"
        "DE:AD:CA:FE:00:02|Dead Cafe"
        "BA:DD:C0:DE:00:01|Bad Code"
        "5E:EB:AD:00:C0:DE|See Bad Code"
        "BA:DA:55:00:00:01|Badass"
        "DE:AD:10:CC:00:01|DEADLOCK"
        "00:DE:AD:FA:CE:00|Dead Face"
        "00:20:91:00:00:00|NSA MAC Prefix"
        "00:C0:ED:00:00:00|Army MAC Prefix"
        "BC:DF:58:00:00:00|Google"
        "DC:10:57:00:00:00|Apple"
        "00:22:00:00:00:00|IBM"
        "D8:B3:70:00:00:00|Ubiquiti"
        "54:07:7D:00:00:00|Netgear"
        "00:23:C2:00:00:00|Samsung"
        "48:DC:FB:00:00:00|Nokia"
        "48:57:DD:00:00:00|Facebook"
        "28:24:C9:00:00:00|Amazon"
        "54:F8:F0:00:00:00|Tesla (Yes, the EV company)"
        "00:09:9a:00:00:00|Elmo... Fucking Elmo."
    )
    local index=1
    for mac in "${macs[@]}"; do
        name=$(echo "$mac" | cut -d'|' -f2)
        address=$(echo "$mac" | cut -d'|' -f1)
        echo "$index: $name ($address)"
        index=$((index + 1))
    done
}

# Function to select a MAC address from the list
function select_mac_address {
    list_cool_macs
    local macs=(
        "DE:AD:BE:EF:DE:AD" #Dead Beef
        "DE:C0:DE:C0:DE:00" #Decode
        "C0:FF:EE:CA:FE:00" #Coffee Cafe
        "BA:DD:C0:FF:EE:00" #Bad Coffee
        "BA:DB:AD:CA:FE:00" #Bad, Bad Cafe
        "CA:FE:BA:BE:00:01" #Cafe Babe
        "FA:CE:B0:0C:00:01" #Facebook
        "DE:AD:CA:FE:00:02" #Dead Cafe
        "BA:DD:C0:DE:00:01" #Bad Code
        "5E:EB:AD:00:C0:DE" #See Bad Code
        "BA:DA:55:00:00:01" #Badass
        "DE:AD:10:CC:00:01" #DEADLOCK
        "00:DE:AD:FA:CE:00" #DEADFACE
        "00:20:91:00:00:00" #NSA Mac Prefix, random data added for last 3 hex pairs
        "00:C0:ED:00:00:00" #Army Mac Prefix
        "BC:DF:58:00:00:00" #Google
        "DC:10:57:00:00:00" #Apple
        "00:22:00:00:00:00" #IBM
        "D8:B3:70:00:00:00" #Ubiquiti
        "54:07:7D:00:00:00" #Netgear
        "00:23:C2:00:00:00" #Samsung
        "48:DC:FB:00:00:00" #Nokia
        "48:57:DD:00:00:00" #Facebook
        "28:24:C9:00:00:00" #Amazon
        "54:F8:F0:00:00:00" #Tesla
        "00:09:9a:00:00:00" #Elmo
    )
    local mac_count=${#macs[@]}
    read -p "Enter the number of the MAC address you want to use (or 0 to enter your own): " mac_num
    if [[ $mac_num -ge 1 && $mac_num -le $mac_count ]]; then
        selected_mac="${macs[$((mac_num - 1))]}"
        echo "Selected MAC address: $selected_mac"
    elif [ "$mac_num" -eq 0 ]; then
        read -p "Enter your own MAC address (XX:XX:XX:XX:XX:XX): " selected_mac
    else
        echo "Invalid selection."
        return 1
    fi
    return 0
}

# Function to check and handle interface state
function handle_interface_state {
    local iface="$1"
    local state=$(get_interface_state "$iface")
    if [ "$state" == "UP" ]; then
        read -p "The interface $iface is currently UP. This may temporarily disconnect you from the internet. Do you want to turn it off temporarily? (y/n): " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo "Turning off the interface $iface..."
            ip link set "$iface" down
            return 0
        else
            echo "Cannot change the MAC address while the interface is UP. Exiting."
            exit 1
        fi
    fi
    return 0
}

# Function to bring the interface back up
function bring_interface_up {
    local iface="$1"
    echo "Bringing the interface $iface back up..."
    ip link set "$iface" up
}

# Function to set a new MAC address
function set_new_mac {
    if [ -n "$interface" ] && [ -n "$selected_mac" ]; then
        if handle_interface_state "$interface"; then
            sudo macchanger -m "$selected_mac" "$interface"
            bring_interface_up "$interface"
            echo "MAC address changed to $selected_mac successfully."
            exit 0
        else
            echo "Failed to set MAC address."
            return 1
        fi
    else
        echo "Failed to set MAC address."
        return 1
    fi
}

# Function to set a random MAC address
function set_random_mac {
    if [ -n "$interface" ]; then
        if handle_interface_state "$interface"; then
            local cmd="sudo macchanger -r $interface"
            if [ "$burned_in" = true ]; then
                cmd+=" -b"
            fi
            eval "$cmd"
            bring_interface_up "$interface"
            echo "MAC address changed to a random value successfully."
            exit 0
        else
            echo "Failed to set MAC address."
            return 1
        fi
    else
        echo "Interface must be specified with -i for setting a random MAC address."
    fi
}

# Function to set a random vendor MAC address
function set_random_vendor_mac {
    if [ -n "$interface" ]; then
        if handle_interface_state "$interface"; then
            sudo macchanger -A "$interface"
            bring_interface_up "$interface"
            echo "MAC address changed to a random vendor value successfully."
            exit 0
        else
            echo "Failed to set MAC address."
            return 1
        fi
    else
        echo "Interface must be specified with -i for setting a random vendor MAC address."
    fi
}

# Function to reset MAC address to permanent hardware address
function reset_permanent_mac {
    if [ -n "$interface" ]; then
        if handle_interface_state "$interface"; then
            sudo macchanger -p "$interface"
            bring_interface_up "$interface"
            echo "MAC address reset to permanent hardware address successfully."
            exit 0
        else
            echo "Failed to reset MAC address."
            return 1
        fi
    else
        echo "Interface must be specified with -i for resetting to permanent MAC address."
    fi
}

# Main script logic
function main {
    # Check if the script is running as root
    check_root "$@"

    # Initialize variables
    burned_in=false
    new_mac_flag=false
    random_mac_flag=false
    random_vendor_mac_flag=false
    reset_permanent_mac_flag=false

    # Parse options
    while getopts "nrvob:i:h" opt; do
        case ${opt} in
            n)
                new_mac_flag=true
                ;;
            r)
                random_mac_flag=true
                ;;
            rv)
                random_vendor_mac_flag=true
                ;;
            o)
                reset_permanent_mac_flag=true
                ;;
            b)
                burned_in=true
                ;;
            i)
                interface=$OPTARG
                ;;
            h)
                display_help
                exit 0
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))

    if [ "$random_mac_flag" = true ]; then
        if [ -n "$interface" ]; then
            if [ "$burned_in" = true ]; then
                set_random_mac
            else
                set_random_mac
            fi
        else
            echo "Interface must be specified with -i for setting a random MAC address."
        fi
    elif [ "$random_vendor_mac_flag" = true ]; then
        if [ -n "$interface" ]; then
            set_random_vendor_mac
        else
            echo "Interface must be specified with -i for setting a random vendor MAC address."
        fi
    elif [ "$reset_permanent_mac_flag" = true ]; then
        if [ -n "$interface" ]; then
            reset_permanent_mac
        else
            echo "Interface must be specified with -i for resetting to permanent MAC address."
        fi
    elif [ "$new_mac_flag" = true ]; then
        if [ -n "$interface" ]; then
            if select_mac_address; then
                set_new_mac
            fi
        else
            echo "Interface must be specified with -i for setting a new MAC address."
        fi
    else
        # Interactive mode
        echo "Did you know: this script can be run with command-line arguments?"
        echo
        while true; do
            echo -e "\nOptions:"
            echo "q: Quit the program"
            echo "n: Set a new MAC address"
            echo "r: Set a random MAC address"
            echo "rv: Set a random vendor MAC address"
            echo "o: Reset MAC address to permanent hardware address"
            read -p "Choose an option (q/n/r/rv/o): " option

            case $option in
                q)
                    echo "No changes were made. Exiting."
                    exit 0
                    ;;
                n)
                    if select_interface && select_mac_address; then
                        set_new_mac
                    fi
                    ;;
                r)
                    if select_interface; then
                        read -p "Do you want to set the MAC address as a burned-in address? (y/n): " answer
                        if [[ "$answer" =~ ^[Yy]$ ]]; then
                            burned_in=true
                        fi
                        set_random_mac
                    fi
                    ;;
                rv)
                    if select_interface; then
                        set_random_vendor_mac
                    fi
                    ;;
                o)
                    if select_interface; then
                        reset_permanent_mac
                    fi
                    ;;
                *)
                    echo "Invalid option. Please enter 'q', 'n', 'r', 'rv', or 'o'."
                    ;;
            esac
        done
    fi
}

# Execute the main function
main "$@"
