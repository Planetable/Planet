import socket
import crayons
import config
import json
import ssl
import time
from nostr.event import Event
from nostr.relay_manager import RelayManager
from nostr.message_type import ClientMessageType
from nostr.key import PrivateKey


def send_nostr_message(message_content, private_key_nsec, relay_url):
    identity_pk = PrivateKey.from_nsec(private_key_nsec)

    relay_manager = RelayManager()
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


def check_connection(address, port):
    try:
        with socket.create_connection((address, port), timeout=10):
            return f"Connection successful: {address} {port}"
    except socket.error as err:
        return f"Error connecting to {address} {port} - {err}"


def main():
    filename = "peers.txt"  # Updated file name
    o = ""
    with open(filename, "r") as file:
        for line in file:
            line = line.strip()
            # Skip lines starting with #
            if line.startswith("#") or line == "":
                o = o + line + "\n"
                continue
            parts = line.split()  # Splits by whitespace
            address = parts[0]
            port = int(parts[1])
            o = o + check_connection(address, port) + "\n"
        send_nostr_message(o, config.nostr_private_key, config.nostr_relay_url)


if __name__ == "__main__":
    main()
