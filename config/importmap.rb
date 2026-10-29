# Pin npm packages by running ./bin/importmap

pin "application"
pin "confirm_dialog"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "three", to: "three.js"
pin "three/addons/controls/OrbitControls.js", to: "three-orbit-controls.js"
