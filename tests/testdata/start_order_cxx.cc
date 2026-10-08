// Copyright 2026 SOFTYONARY SL
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Real-Celix C++ activator for the runner C++ start integration test. Uses the
// celix::impl::createActivator path (issue #13's crash site), registers a
// service (the registerService -> ServiceRegistrationBuilder path) and logs a
// fixed marker line on construction.
#include <cstdio>
#include <memory>
#include <string>
#include <utility>

#include <celix/BundleActivator.h>
#include <celix/BundleContext.h>
#include <celix/ServiceRegistration.h>

namespace {
struct Greeter {
    // Anonymous-namespace types can't be named via celix::impl::extractTypeName
    // (__PRETTY_FUNCTION__ isn't usable there), so declare the service name
    // explicitly; registerService<Greeter> falls back to it.
    static constexpr const char* NAME = "Greeter";

    virtual ~Greeter() = default;
    virtual void hello() const = 0;
};

class GreeterImpl : public Greeter {
public:
    void hello() const override {}
};
} // namespace

class start_order_cxx_activator {
public:
    explicit start_order_cxx_activator(std::shared_ptr<celix::BundleContext> ctx)
        : ctx{std::move(ctx)} {
        // `this->ctx` — never the parameter, which the member init moved-from.
        auto greeter = std::make_shared<GreeterImpl>();
        reg = this->ctx->registerService<Greeter>(std::move(greeter))
                  .addProperty("greeting", std::string{"hello"})
                  .build();
        printf("rules_celix start-order: cxx\n");
        fflush(stdout);
    }
    ~start_order_cxx_activator() {
        if (reg) {
            reg.reset();
        }
    }

private:
    std::shared_ptr<celix::BundleContext> ctx;
    std::shared_ptr<celix::ServiceRegistration> reg;
};

CELIX_GEN_CXX_BUNDLE_ACTIVATOR(start_order_cxx_activator)
