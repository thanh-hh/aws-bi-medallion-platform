import argparse
import io
from datetime import datetime, timezone

import boto3
import pandas as pd

s3 = boto3.client("s3")


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--BRONZE_BUCKET", required=False)
    parser.add_argument("--SILVER_BUCKET", required=True)
    parser.add_argument("--GOLD_BUCKET", required=True)
    parser.add_argument("--RUN_DATE", required=False)
    parser.add_argument("--ENV", required=False)
    parser.add_argument("--JOB_LAYER", required=False)
    return parser.parse_known_args()[0]


def read_parquet(bucket: str, key: str) -> pd.DataFrame:
    obj = s3.get_object(Bucket=bucket, Key=key)
    return pd.read_parquet(io.BytesIO(obj["Body"].read()), engine="pyarrow")


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


def main():
    args = parse_args()
    run_date = args.RUN_DATE or datetime.now(timezone.utc).date().isoformat()

    sales = read_parquet(args.SILVER_BUCKET, f"tables/sales/run_date={run_date}/part-000.parquet")
    product = read_parquet(args.SILVER_BUCKET, f"tables/dim_product/run_date={run_date}/part-000.parquet")
    manufacturer = read_parquet(args.SILVER_BUCKET, f"tables/dim_manufacturer/run_date={run_date}/part-000.parquet")
    date_dim = read_parquet(args.SILVER_BUCKET, f"tables/dim_date/run_date={run_date}/part-000.parquet")

    df = sales.merge(product.drop(columns=["load_date"]), on="product_id", how="left")
    df = df.merge(manufacturer.drop(columns=["load_date"]), on="manufacturer_id", how="left")
    df = df.merge(date_dim.drop(columns=["load_date"]), left_on="sale_date", right_on="date_key", how="left")
    df["revenue_per_unit"] = df.apply(lambda r: None if r["units"] == 0 else r["revenue"] / r["units"], axis=1)
    df["load_date"] = pd.to_datetime(run_date).date()

    df = df[[
        "sale_date", "year", "quarter", "month", "product_id", "product", "category", "segment",
        "manufacturer_id", "manufacturer", "zip", "revenue", "units", "revenue_per_unit", "load_date"
    ]]

    # Historical partition for lineage/audit.
    mart_prefix = f"marts/sales_enriched/run_date={run_date}/"
    write_parquet(args.GOLD_BUCKET, mart_prefix, df)

    # Current pointer for idempotent Redshift full-refresh COPY.
    # Re-running the same pipeline replaces this prefix, not duplicates it.
    current_prefix = "marts/sales_enriched/current/"
    write_parquet(args.GOLD_BUCKET, current_prefix, df)

    print(f"Wrote gold mart: s3://{args.GOLD_BUCKET}/{mart_prefix}; rows={len(df)}")
    print(f"Wrote current mart: s3://{args.GOLD_BUCKET}/{current_prefix}; rows={len(df)}")


if __name__ == "__main__":
    main()
