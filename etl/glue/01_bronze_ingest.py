import argparse
import io
import re
from datetime import datetime, timezone

import boto3
import pandas as pd

s3 = boto3.client("s3")


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--BRONZE_BUCKET", required=True)
    parser.add_argument("--SILVER_BUCKET", required=False)
    parser.add_argument("--GOLD_BUCKET", required=False)
    parser.add_argument("--RUN_DATE", required=False)
    parser.add_argument("--INPUT_KEY", required=True)
    parser.add_argument("--ENV", required=False)
    parser.add_argument("--JOB_LAYER", required=False)
    return parser.parse_known_args()[0]


def normalized_name(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", str(name).strip().lower()).strip("_")


def put_df_csv(bucket: str, key: str, df: pd.DataFrame):
    buf = io.StringIO()
    df.to_csv(buf, index=False)
    s3.put_object(Bucket=bucket, Key=key, Body=buf.getvalue().encode("utf-8"))


def main():
    args = parse_args()
    run_date = args.RUN_DATE or datetime.now(timezone.utc).date().isoformat()

    obj = s3.get_object(Bucket=args.BRONZE_BUCKET, Key=args.INPUT_KEY)
    raw_bytes = obj["Body"].read()

    # Keep immutable original source in bronze/source partition.
    source_key = f"source/run_date={run_date}/Data.xlsx"
    s3.put_object(Bucket=args.BRONZE_BUCKET, Key=source_key, Body=raw_bytes)

    # Also split sheets into bronze CSV for lineage and easier downstream processing.
    workbook = pd.read_excel(io.BytesIO(raw_bytes), sheet_name=None, engine="openpyxl")
    for sheet_name, df in workbook.items():
        table = normalized_name(sheet_name)
        df.columns = [normalized_name(c) for c in df.columns]
        out_key = f"tables/{table}/run_date={run_date}/part-000.csv"
        put_df_csv(args.BRONZE_BUCKET, out_key, df)
        print(f"Wrote bronze table: s3://{args.BRONZE_BUCKET}/{out_key}; rows={len(df)}")


if __name__ == "__main__":
    main()
