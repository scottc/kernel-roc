app [main!] { pf: platform "../platform/main.roc" }

import pf.Write

main! = |_| {
    Write.write!("Hello from Roc App on bare metal!\n")
}
