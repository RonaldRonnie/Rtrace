import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";
import slugify from "slugify";

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash("password123", 12);

  const user = await prisma.user.upsert({
    where: { email: "demo@tracecloud.dev" },
    update: {},
    create: {
      email: "demo@tracecloud.dev",
      name: "Demo User",
      passwordHash,
    },
  });

  const orgSlug = slugify("Demo Org", { lower: true, strict: true });
  const org = await prisma.organization.upsert({
    where: { slug: orgSlug },
    update: {},
    create: {
      name: "Demo Org",
      slug: orgSlug,
      plan: "TEAM",
    },
  });

  await prisma.orgMember.upsert({
    where: { orgId_userId: { orgId: org.id, userId: user.id } },
    update: {},
    create: { orgId: org.id, userId: user.id, role: "OWNER" },
  });

  const projectSlug = slugify("my-r-package", { lower: true, strict: true });
  await prisma.project.upsert({
    where: { orgId_slug: { orgId: org.id, slug: projectSlug } },
    update: {},
    create: {
      orgId: org.id,
      name: "my-r-package",
      slug: projectSlug,
      description: "Example R package for Trace Cloud demo",
      scanRoot: ".",
      defaultBranch: "main",
    },
  });

  console.log("Seed complete. Demo credentials: demo@tracecloud.dev / password123");
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
