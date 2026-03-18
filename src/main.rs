use rumqttc::{Client, Event, MqttOptions, Packet, QoS};
use std::time::Duration;

fn handle_event(event: Event) {
    println!("Handling event: {:?}", event);
    match event {
        Event::Incoming(Packet::Publish(msg)) => {
            let topic = msg.topic.clone();
            let payload = String::from_utf8_lossy(&msg.payload);
            let plant_id = topic.split('/').nth(1).unwrap_or("unknown");
            println!("Received message from plant '{}': {}", plant_id, payload);
            // store in sqlite database
        },
        _ => {
            println!("Received non-incoming event: {:?}", event);
        }
    }
}

fn main() {
    let mqtt_client_id = env!("MQTT_CLIENT_ID");
    let mqtt_host = env!("MQTT_HOST");
    let keep_alive_min = env!("MQTT_KEEP_ALIVE_MIN").parse::<u64>().unwrap_or(15);

    let mut mqttoptions = MqttOptions::new(mqtt_client_id, mqtt_host, 1883);
    mqttoptions.set_keep_alive(Duration::from_mins(keep_alive_min));

    let jukka_topic: &str = "jukka/#";

    let (client, mut connection) = Client::new(mqttoptions, 10);
    client.subscribe(jukka_topic, QoS::AtMostOnce).unwrap();

    loop {
        match connection.iter().next() {
            Some(Ok(event)) => handle_event(event),
            Some(Err(e)) => println!("Error = {:?}", e),
            None => break,
        }
    }
}
