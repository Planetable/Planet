import arrow
from datetime import datetime
import pytz
import socket
import crayons
import config
import ssl
import time
from nostr.event import Event
from nostr.relay_manager import RelayManager
from nostr.message_type import ClientMessageType
from nostr.key import PrivateKey


def send_nostr_message(message_content, private_key_nsec):
    print("Message: \n\n" + message_content)

    identity_pk = PrivateKey.from_nsec(private_key_nsec)

    relay_manager = RelayManager()
    for relay_url in config.nostr_relay_urls:
        relay_manager.add_relay(relay_url)
    relay_manager.open_connections(
        {"cert_reqs": ssl.CERT_NONE}
    )  # NOTE: This disables ssl certificate verification
    time.sleep(1.25)  # allow the connections to open

    event = Event(content=message_content, public_key=identity_pk.public_key.hex())
    identity_pk.sign_event(event)

    relay_manager.publish_event(event)
    time.sleep(1)  # allow the messages to send

    relay_manager.close_connections()
    print(crayons.green("Message sent to Nostr relays"))


def check_connection(address, port):
    try:
        with socket.create_connection((address, port), timeout=10):
            return f"✅ Connection successful: {address} {port}"
    except socket.error as err:
        return f"☹️ Error connecting to {address} {port} - {err}"


def format_timestamp(unix_timestamp):
    # Convert the Unix timestamp to a datetime object
    date = datetime.fromtimestamp(unix_timestamp, pytz.timezone("US/Pacific"))
    # Format the date and time in the specified format
    return date.strftime("%a - %b %d - %I:%M %p - %Z")


def main():
    filename = "peers.txt"
    now = int(time.time())
    o = format_timestamp(now) + "\n\n"
    with open(filename, "r") as file:
        for line in file:
            line = line.strip()
            # Skip lines starting with #
            if line.startswith("#") or line.startswith("//") or line == "":
                o = o + line + "\n"
                continue
            parts = line.split()  # Splits by whitespace
            address = parts[0]
            port = int(parts[1])
            o = o + check_connection(address, port) + "\n"
        send_nostr_message(o, config.nostr_private_key)


if __name__ == "__main__":
    main()
