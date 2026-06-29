import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding Panggil-In database...');

  // 1. Create Police Operator
  const operatorEmail = 'operator@panggil.in';
  const existingOperator = await prisma.user.findUnique({
    where: { email: operatorEmail },
  });

  if (!existingOperator) {
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash('operator123', salt);
    await prisma.user.create({
      data: {
        email: operatorEmail,
        password: hashedPassword,
        name: 'Aiptu Budi Prasetyo',
        phone: '081234567890',
        role: 'POLICE_OPERATOR',
        reputation_score: 100.0,
      },
    });
    console.log('Police Operator seeded: operator@panggil.in / operator123');
  } else {
    console.log('Operator user already exists.');
  }

  // 2. Create Citizen (for reporting testing)
  const citizenEmail = 'citizen@panggil.in';
  const existingCitizen = await prisma.user.findUnique({
    where: { email: citizenEmail },
  });

  if (!existingCitizen) {
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash('citizen123', salt);
    await prisma.user.create({
      data: {
        email: citizenEmail,
        password: hashedPassword,
        name: 'Rian Wijaya',
        phone: '089876543210',
        role: 'CITIZEN',
        reputation_score: 85.0,
        riding_mode: false,
      },
    });
    console.log('Citizen seeded: citizen@panggil.in / citizen123');
  }

  // 3. Create Super Admin
  const adminEmail = 'superadmin@panggil.in';
  const existingAdmin = await prisma.user.findUnique({
    where: { email: adminEmail },
  });

  if (!existingAdmin) {
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash('superadmin123', salt);
    await prisma.user.create({
      data: {
        email: adminEmail,
        password: hashedPassword,
        name: 'Super Admin',
        phone: '081122334455',
        role: 'SUPERADMIN',
        reputation_score: 100.0,
      },
    });
    console.log('Super Admin seeded: superadmin@panggil.in / superadmin123');
  }

  // 4. Create CCTV Cameras
  // Coordinates are near Bandung (Dago area)
  const cctvs = [
    {
      id: 'cctv-uuid-dago-11',
      name: 'Simpang Dago Utara 01',
      stream_url: 'http://localhost:3001/static/cctv_begal.mp4',
      latitude: -6.8868,
      longitude: 107.6153,
      fps_mode: 'LOW',
      status: 'ACTIVE',
    },
    {
      id: 'cctv-uuid-dago-12',
      name: 'Simpang Dago Selatan 02',
      stream_url: 'http://localhost:3001/static/cctv_begal.mp4',
      latitude: -6.8892,
      longitude: 107.6161,
      fps_mode: 'LOW',
      status: 'ACTIVE',
    },
    {
      id: 'cctv-uuid-pasupati-21',
      name: 'Flyover Pasupati Barat 03',
      stream_url: 'http://localhost:3001/static/cctv_begal.mp4',
      latitude: -6.8994,
      longitude: 107.6098,
      fps_mode: 'LOW',
      status: 'ACTIVE',
    },
  ];

  for (const cctv of cctvs) {
    await prisma.cCTVCamera.upsert({
      where: { id: cctv.id },
      update: {
        stream_url: cctv.stream_url,
      },
      create: cctv,
    });
  }
  console.log('CCTV Cameras seeded.');

  // 5. Create Patrol Units
  const patrolUnits = [
    {
      id: 'patrol-unit-1',
      name: 'Patroli Sabhara Resta 901',
      latitude: -6.8850,
      longitude: 107.6180,
      status: 'AVAILABLE',
      phone: '08111222333',
    },
    {
      id: 'patrol-unit-2',
      name: 'Patroli Motor Lantas 902',
      latitude: -6.8900,
      longitude: 107.6120,
      status: 'AVAILABLE',
      phone: '08111222444',
    },
    {
      id: 'patrol-unit-3',
      name: 'Tim Prabu Resmob 903',
      latitude: -6.9010,
      longitude: 107.6100,
      status: 'AVAILABLE',
      phone: '08111222555',
    },
  ];

  for (const unit of patrolUnits) {
    await prisma.patrolUnit.upsert({
      where: { id: unit.id },
      update: {},
      create: unit,
    });
  }
  console.log('Patrol Units seeded.');

  console.log('Database seeding successfully finished!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
