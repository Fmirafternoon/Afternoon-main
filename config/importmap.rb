# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/activestorage", to: "@rails--activestorage.js" # @8.0.100
pin "axios", to: "https://unpkg.com/axios@1.8.1/dist/esm/axios.min.js"
pin "@rails/request.js", to: "https://ga.jspm.io/npm:@rails/request.js@0.0.11/src/index.js"
pin "imask", to: "https://cdn.jsdelivr.net/npm/imask@7.6.1/+esm"
pin "stimulus-use", to: "https://ga.jspm.io/npm:stimulus-use@0.52.3/dist/index.js"
pin "trix", to: "https://cdn.jsdelivr.net/npm/trix@2.1.10/dist/trix.esm.min.js"
pin "tippy.js", to: "https://cdn.jsdelivr.net/npm/tippy.js@6.3.7/+esm"
pin_all_from "app/javascript/controllers", under: "controllers"
