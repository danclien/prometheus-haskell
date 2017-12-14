{-# language DeriveGeneric #-}
{-# language DeriveAnyClass #-}
{-# language OverloadedStrings #-}

module Prometheus.Export.TextSpec (
    spec
) where

import Prometheus

import GHC.Generics
import Test.Hspec
import qualified Data.Text.Lazy as LT
import qualified Data.Text.Lazy.Encoding as LT

data HTTP = HTTP { handler :: String, method :: String }
  deriving (Generic, Ord, Eq)
instance Label HTTP

spec :: Spec
spec = before_ unregisterAll $ after_ unregisterAll $
  describe "Prometheus.Export.Text.exportMetricsAsText" $ do
      it "renders counters" $ do
            m <- register $ counter (Info "test_counter" "help string")
            incCounter m
            result <- exportMetricsAsText
            result `shouldBe` LT.encodeUtf8 (LT.pack $ unlines [
                    "# HELP test_counter help string"
                ,   "# TYPE test_counter counter"
                ,   "test_counter 1.0"
                ])
      it "renders gauges" $ do
            m <- register $ gauge (Info "test_gauge" "help string")
            setGauge m 47
            result <- exportMetricsAsText
            result `shouldBe` LT.encodeUtf8 (LT.pack $ unlines [
                    "# HELP test_gauge help string"
                ,   "# TYPE test_gauge gauge"
                ,   "test_gauge 47.0"
                ])
      it "renders summaries" $ do
            m <- register $ summary (Info "metric" "help") defaultQuantiles
            observe m 1
            observe m 1
            observe m 1
            result <- exportMetricsAsText
            result `shouldBe` LT.encodeUtf8 (LT.pack $ unlines [
                    "# HELP metric help"
                ,   "# TYPE metric summary"
                ,   "metric{quantile=\"0.5\"} 1.0"
                ,   "metric{quantile=\"0.9\"} 1.0"
                ,   "metric{quantile=\"0.99\"} 1.0"
                ,   "metric_sum 3.0"
                ,   "metric_count 3"
                ])
      it "renders histograms" $ do
            m <- register $ histogram (Info "metric" "help") defaultBuckets
            observe m 1.0
            observe m 1.0
            observe m 1.0
            result <- exportMetricsAsText
            result `shouldBe` LT.encodeUtf8 (LT.pack $ unlines [
                    "# HELP metric help"
                ,   "# TYPE metric histogram"
                ,   "metric_bucket{le=\"0.005\"} 0"
                ,   "metric_bucket{le=\"0.01\"} 0"
                ,   "metric_bucket{le=\"0.025\"} 0"
                ,   "metric_bucket{le=\"0.05\"} 0"
                ,   "metric_bucket{le=\"0.1\"} 0"
                ,   "metric_bucket{le=\"0.25\"} 0"
                ,   "metric_bucket{le=\"0.5\"} 0"
                ,   "metric_bucket{le=\"1.0\"} 3"
                ,   "metric_bucket{le=\"2.5\"} 3"
                ,   "metric_bucket{le=\"5.0\"} 3"
                ,   "metric_bucket{le=\"10.0\"} 3"
                ,   "metric_bucket{le=\"+Inf\"} 3"
                ,   "metric_sum 3.0"
                ,   "metric_count 3"
                ])
      it "renders vectors" $ do
            m <- register $ vector
                          $ counter (Info "test_counter" "help string")
            withLabel m (HTTP "root" "GET") incCounter
            result <- exportMetricsAsText
            result `shouldBe` LT.encodeUtf8 (LT.pack $ unlines [
                    "# HELP test_counter help string"
                ,   "# TYPE test_counter counter"
                ,   "test_counter{handler=\"root\",method=\"GET\"} 1.0"
                ])
      it "escapes newlines and slashes from help strings" $ do
            _ <- register $ counter (Info "metric" "help \n \\string")
            result <- exportMetricsAsText
            result `shouldBe` LT.encodeUtf8 (LT.pack $ unlines [
                    "# HELP metric help \\n \\\\string"
                ,   "# TYPE metric counter"
                ,   "metric 0.0"
                ])
