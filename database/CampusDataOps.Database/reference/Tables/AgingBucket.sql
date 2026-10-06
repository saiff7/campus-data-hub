-- Account aging buckets by days past due on the as-of date. A NULL bound is open-ended.
-- Buckets must not overlap; the aging tests check every boundary day.
CREATE TABLE [reference].[AgingBucket] (
    [BucketCode]     VARCHAR (10)  NOT NULL,
    [BucketName]     NVARCHAR (50) NOT NULL,
    [MinDaysPastDue] INT           NULL,
    [MaxDaysPastDue] INT           NULL,
    [SortOrder]      TINYINT       NOT NULL,
    [CreatedAtUtc]   DATETIME2 (3) CONSTRAINT [DF_reference_AgingBucket_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]   DATETIME2 (3) CONSTRAINT [DF_reference_AgingBucket_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_AgingBucket] PRIMARY KEY CLUSTERED ([BucketCode] ASC),
    CONSTRAINT [UQ_reference_AgingBucket_SortOrder] UNIQUE ([SortOrder]),
    CONSTRAINT [CK_reference_AgingBucket_Range]
        CHECK ([MinDaysPastDue] IS NULL OR [MaxDaysPastDue] IS NULL OR [MinDaysPastDue] <= [MaxDaysPastDue])
);
