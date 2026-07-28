"use client";

import { deploymentGaps } from "@/lib/deployments";
import { StatusBadge } from "./StatusBadge";

/**
 * Renders a banner + blocks children when any required Shibui address or
 * schema UID is still zero in deployments/sepolia.json. The banner lists what
 * needs to be deployed before that page is useful.
 *
 * Pass `required` to narrow to a subset (e.g. attester page doesn't need the
 * demo token). Default is "all", which is the safe fallback.
 */
export function ConfigurationGate({
  children,
  required,
}: {
  children: React.ReactNode;
  required?: Array<"verifier" | "adapter" | "proxy" | "schemas" | "token">;
}) {
  const allGaps = deploymentGaps();
  const gaps = required
    ? allGaps.filter((g) => {
        if (required.includes("verifier") && g.path.includes("ClaimVerifier"))
          return true;
        if (required.includes("adapter") && g.path.includes("IssuersAdapter"))
          return true;
        if (required.includes("proxy") && g.path.includes("IdentityProxy"))
          return true;
        if (required.includes("schemas") && g.path.startsWith("schemas."))
          return true;
        if (required.includes("token") && g.path.includes("Token"))
          return true;
        return false;
      })
    : allGaps;

  if (gaps.length === 0) return <>{children}</>;

  return (
    <div className="space-y-6">
      <div className="card border-amber-200 bg-amber-50">
        <div className="flex items-start gap-3">
          <StatusBadge tone="warn">Not deployed</StatusBadge>
          <div className="space-y-2">
            <h3 className="font-semibold">
              This page needs Sepolia deployment data before it can run.
            </h3>
            <p className="text-sm text-slate-700">
              Populate the following fields in{" "}
              <code className="font-mono">deployments/sepolia.json</code>, then
              refresh:
            </p>
            <ul className="ml-5 list-disc text-sm font-mono text-slate-800">
              {gaps.map((g) => (
                <li key={g.path}>
                  {g.label}{" "}
                  <span className="text-slate-500">({g.path})</span>
                </li>
              ))}
            </ul>
            <p className="text-sm text-slate-700">
              Deploy the stack with{" "}
              <code className="font-mono">
                forge script script/DeployTestnet.s.sol
              </code>{" "}
              +{" "}
              <code className="font-mono">
                script/RegisterSchemas.s.sol
              </code>{" "}
              +{" "}
              <code className="font-mono">script/deploy/DeployDemo.s.sol</code>{" "}
              — see the demo README for the full setup sequence.
            </p>
          </div>
        </div>
      </div>
      <div className="opacity-50 pointer-events-none select-none">
        {children}
      </div>
    </div>
  );
}
