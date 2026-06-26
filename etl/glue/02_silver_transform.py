import argparse
import io
from datetime import datetime, timezone

import boto3
import pandas as pd

s3 = boto3.client("s3")

TABLES = ["sales", "dim_product", "dim_manufacturer", "dim_date"]


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--BRONZE_BUCKET", required=True)
    parser.add_argument("--SILVER_BUCKET", required=True)
    parser.add_argument("--GOLD_BUCKET", required=False)
    parser.add_argument("--RUN_DATE", required=False)
    parser.add_argument("--ENV", required=False)
    parser.add_argument("--JOB_LAYER", required=False)
    return parser.parse_known_args()[0]


def read_csv(bucket: str, key: str) -> pd.DataFrame:
    obj = s3.get_object(Bucket=bucket, Key=key)
    return pd.read_csv(io.BytesIO(obj["Body"].read()))


def normalize_id(series: pd.Series) -> pd.Series:
    return (
        series.astype("string")
        .str.strip()
        .str.replace(r"\.0$", "", regex=True)
    )


def delete_prefix(bucket: str, prefix: str):
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        objects = [{"Key": item["Key"]} for item in page.get("Contents", [])]
        if objects:
            s3.delete_objects(Bucket=bucket, Delete={"Objects": objects})


def write_parquet(bucket: str, prefix: str, df: pd.DataFrame):
    delete_prefix(bucket, prefix)
    buf = io.BytesIO()
    df.to_parquet(buf, index=False, engine="pyarrow")
    s3.put_object(Bucket=bucket, Key=f"{prefix}part-000.parquet", Body=buf.getvalue())


def transform_sales(df: pd.DataFrame, run_date: str) -> pd.DataFrame:
    df = df.rename(columns={
        "date": "sale_date",
        "productid": "product_id",
        "product_id": "product_id",
        "zip": "zip",
        "revenue": "revenue",
        "units": "units",
    })
    df["sale_date"] = pd.to_datetime(df["sale_date"]).dt.date
    df["product_id"] = normalize_id(df["product_id"])
    df["zip"] = normalize_id(df["zip"])
    df["revenue"] = pd.to_numeric(df["revenue"], errors="coerce").fillna(0.0)
    df["units"] = pd.to_numeric(df["units"], errors="coerce").fillna(0).astype(int)
    df["load_date"] = pd.to_datetime(run_date).date()
    return df[["sale_date", "product_id", "zip", "revenue", "units", "load_date"]]


def transform_product(df: pd.DataFrame, run_date: str) -> pd.DataFrame:
    df = df.rename(columns={
        "productid": "product_id",
        "product_id": "product_id",
        "product": "product",
        "category": "category",
        "segment": "segment",
        "manufacturerid": "manufacturer_id",
        "manufacturer_id": "manufacturer_id",
    })
    df["product_id"] = normalize_id(df["product_id"])
    df["manufacturer_id"] = normalize_id(df["manufacturer_id"])
    df["load_date"] = pd.to_datetime(run_date).date()
    return df[["product_id", "product", "category", "segment", "manufacturer_id", "load_date"]]


def transform_manufacturer(df: pd.DataFrame, run_date: str) -> pd.DataFrame:
    df = df.rename(columns={
        "manufacturerid": "manufacturer_id",
        "manufacturer_id": "manufacturer_id",
        "manufacturer": "manufacturer",
    })
    df["manufacturer_id"] = normalize_id(df["manufacturer_id"])
    df["load_date"] = pd.to_datetime(run_date).date()
    return df[["manufacturer_id", "manufacturer", "load_date"]]


def transform_date(df: pd.DataFrame, run_date: str) -> pd.DataFrame:
    date_col = "date" if "date" in df.columns else df.columns[0]
    df = df.rename(columns={date_col: "date_key"})
    df["date_key"] = pd.to_datetime(df["date_key"]).dt.date
    dt = pd.to_datetime(df["date_key"])
    df["year"] = dt.dt.year
    df["quarter"] = dt.dt.quarter
    df["month"] = dt.dt.month
    df["month_name"] = dt.dt.month_name()
    df["load_date"] = pd.to_datetime(run_date).date()
    return df[["date_key", "year", "quarter", "month", "month_name", "load_date"]]


def main():
    args = parse_args()
    run_date = args.RUN_DATE or datetime.now(timezone.utc).date().isoformat()

    transforms = {
        "sales": transform_sales,
        "dim_product": transform_product,
        "dim_manufacturer": transform_manufacturer,
        "dim_date": transform_date,
    }

    for table in TABLES:
        src_key = f"tables/{table}/run_date={run_date}/part-000.csv"
        df = read_csv(args.BRONZE_BUCKET, src_key)
        out = transforms[table](df, run_date)
        out_prefix = f"tables/{table}/run_date={run_date}/"
        write_parquet(args.SILVER_BUCKET, out_prefix, out)
        print(f"Wrote silver table: s3://{args.SILVER_BUCKET}/{out_prefix}; rows={len(out)}")


if __name__ == "__main__":
    main()
