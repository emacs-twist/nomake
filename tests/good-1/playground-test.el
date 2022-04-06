;;; -*- lexical-binding: t -*-

(require 'buttercup)
(require 'playground)

(describe "Do nothing"
  (it "does nothing"
    (expect t :to-be t)))

(provide 'playground-test)
