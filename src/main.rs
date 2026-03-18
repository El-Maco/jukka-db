mod db;

use rumqttc::{AsyncClient, Event, MqttOptions, Packet, QoS};
use sqlx::{Pool, Sqlite};
use std::time::Duration;

use crate::db::{get_plant_by_name, init_db, insert_measurement, insert_plant};

async fn get_or_insert_plant(pool: &Pool<Sqlite>, name: &str) -> Result<u32, sqlx::Error> {
    match get_plant_by_name(pool, name).await? {
        Some(plant) => Ok(plant.id),
        None => insert_plant(pool, name).await,
    }
}

async fn handle_event(pool: &Pool<Sqlite>, event: &Event) {
    // println!("Handling event: {:?}", event);
    match event {
        Event::Incoming(Packet::Publish(msg)) => {
            let topic = msg.topic.clone();
            let payload = String::from_utf8_lossy(&msg.payload);
            let plant_name = topic.split('/').nth(1).unwrap_or("unknown");
            println!("Received message from plant '{}': {}", plant_name, payload);
            let plant_id =  get_or_insert_plant(pool, plant_name).await.unwrap();
            // println!("Plant ID for '{}': {}", plant_name, plant_id);
            let measurement: u32 = payload.parse().unwrap();
            println!("Inserting plant ID {}, name {}, measurement {}", plant_id, plant_name, measurement);
            insert_measurement(pool, plant_id, measurement).await.unwrap();
        }
        _ => {
            // println!("Received non-incoming event: {:?}", event);
        }
    }
}

#[tokio::main]
async fn main() {
    let mqtt_client_id = env!("MQTT_CLIENT_ID");
    let mqtt_host = env!("MQTT_HOST");
    let keep_alive_min = env!("MQTT_KEEP_ALIVE_MIN").parse::<u64>().unwrap_or(15);
    let db_url = env!("DATABASE_URL");

    let db_connection: Pool<Sqlite> = init_db(db_url).await.unwrap();

    let mut options = MqttOptions::new(mqtt_client_id, mqtt_host, 1883);
    options.set_keep_alive(Duration::from_mins(keep_alive_min));

    let jukka_topic: &str = "jukka/#";

    let (client, mut eventloop) = AsyncClient::new(options, 10);
    client.subscribe(jukka_topic, QoS::AtMostOnce).await.unwrap();

    loop {
        match eventloop.poll().await {
            Ok(event) => handle_event(&db_connection, &event).await,
            Err(e) => println!("Error = {:?}", e),
        }
    }
}
