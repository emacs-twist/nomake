;;; -*- lexical-binding: t -*-

(require 'buttercup)
(require 'playground)

(describe "Do nothing"
  (it "does nothing"
    (expect t :to-be t)))

(describe "runtimeInputsFromPkgs"
  (it "makes extra executables available"
    (expect (executable-find "hello")
            :to-be-truthy)))

(provide 'playground-test)
