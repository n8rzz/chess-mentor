# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "chart.js", to: "chart.js.js"
pin "chess.js", to: "chess.js.js"
# Bundled via: npx esbuild vendor/javascript/cm-chessboard-entry.js --bundle --format=esm --outfile=vendor/javascript/cm-chessboard.bundle.js
pin "cm-chessboard", to: "cm-chessboard.bundle.js"
pin_all_from "app/javascript/controllers", under: "controllers"
