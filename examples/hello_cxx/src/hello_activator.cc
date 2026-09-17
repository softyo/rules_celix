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

// C++ bundle activator for the hello_cxx example.
//
// Written against the Apache Celix 2.4.0 C++ API: implements an RAII
// `celix::BundleActivator` whose constructor doubles as the bundle "start"
// hook and whose destructor is the "stop" hook. It registers a service into
// the bundle context to exercise the service-registration path.

#include <memory>
#include <string>
#include <utility>

#include <celix/BundleActivator.h>
#include <celix/BundleContext.h>
#include <celix/ServiceRegistration.h>

namespace {

struct Greeter {
    virtual ~Greeter() = default;
    virtual void hello() const = 0;
};

class GreeterImpl : public Greeter {
public:
    void hello() const override {
        // A real bundle would do something more interesting here.
    }
};

} // namespace

class HelloActivator {
public:
    explicit HelloActivator(std::shared_ptr<celix::BundleContext> ctx)
        : ctx{std::move(ctx)} {
        // Register a Greeter service, keeping the registration alive for the
        // lifetime of the activator.
        auto greeter = std::make_shared<GreeterImpl>();
        reg = ctx->registerService<Greeter>(std::move(greeter))
                  .addProperty("greeting", std::string{"Hello from the C++ bundle"})
                  .build();

        ctx->logInfo("Hello CXX activator started in bundle id %li", ctx->getBundleId());
    }

    ~HelloActivator() {
        ctx->logInfo("Hello CXX activator stopped in bundle id %li", ctx->getBundleId());
        reg.reset();
    }

private:
    std::shared_ptr<celix::BundleContext> ctx;
    std::shared_ptr<celix::ServiceRegistration> reg;
};

CELIX_GEN_CXX_BUNDLE_ACTIVATOR(HelloActivator)
