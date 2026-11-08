use sqlx::{Pool, Sqlite, SqlitePool, migrate::MigrateDatabase, prelude::FromRow};

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct Plant {
    pub id: u32,
    pub name: String,
    pub min_reading: u32,
    pub max_reading: u32,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct Measurement {
    pub id: String,
    pub plant_id: String,
    pub value: u32,
    pub timestamp: String,
}

pub async fn init_db(url: &str) -> Result<Pool<Sqlite>, sqlx::Error> {
    if !Sqlite::database_exists(url).await.unwrap_or(false) {
        println!("Creating database {}", url);
        match Sqlite::create_database(url).await {
            Ok(_) => println!("Created db success"),
            Err(error) => panic!("error: {}", error),
        }
    } else {
        println!("Database already exists");
    }

    let pool = SqlitePool::connect(url).await.unwrap();
    // sqlx creates new files in WAL; the journal-mode migration can't run inside a transaction.
    sqlx::query("PRAGMA journal_mode = DELETE").execute(&pool).await?;
    println!("Migrating");
    let migrator = sqlx::migrate!();
    migrator.run(&pool).await?;
    println!("Migration DONE!");

    Ok(pool)
}

/***************************************************
*                   PLANT QUERIES                  *
***************************************************/
#[allow(dead_code)]
pub async fn get_all_plants(pool: &Pool<Sqlite>) -> Result<Vec<Plant>, sqlx::Error> {
    let plants = sqlx::query_as::<_, Plant>("SELECT * FROM plant").fetch_all(pool).await?;
    Ok(plants)
}

pub async fn get_plant_by_name(pool: &Pool<Sqlite>, name: &str) -> Result<Option<Plant>, sqlx::Error> {
    let plant = sqlx::query_as::<_, Plant>("SELECT * FROM plant WHERE name = ?")
        .bind(name)
        .fetch_optional(pool)
        .await?;
    Ok(plant)
}

const MIN_READING_DEFAULT: u32 = 3000;
const MAX_READING_DEFAULT: u32 = 4095;
pub async fn insert_plant(
    pool: &Pool<Sqlite>,
    name: &str,
) -> Result<u32, sqlx::Error> {
    sqlx::query!(
        "INSERT INTO plant (name, min_reading, max_reading) VALUES (?, ?, ?)",
        name,
        MIN_READING_DEFAULT,
        MAX_READING_DEFAULT,
    )
    .execute(pool)
    .await?;
    let plant = get_plant_by_name(pool, name).await?;
    plant.map(|p| p.id).ok_or_else(|| sqlx::Error::RowNotFound)
}


/***************************************************
*             MEASUREMENT QUERIES                  *
***************************************************/
pub async fn insert_measurement(
    pool: &Pool<Sqlite>,
    plant_id: u32,
    measurement: u32,
) -> Result<(), sqlx::Error> {
    sqlx::query!(
        "INSERT INTO measurement (plant_id, value) VALUES (?, ?)",
        plant_id,
        measurement,
    )
    .execute(pool)
    .await?;
    Ok(())
}
