import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

const SEED_PASSWORD = 'Test1234!';

const USERS = [
  { username: 'ahmet',  email: 'ahmet@example.com',  phone: '05551110001', fullName: 'Ahmet Yilmaz',   bio: 'Yazilim gelistirici' },
  { username: 'ayse',   email: 'ayse@example.com',   phone: '05551110002', fullName: 'Ayse Demir',     bio: 'Merhaba!' },
  { username: 'mehmet', email: 'mehmet@example.com', phone: '05551110003', fullName: 'Mehmet Kaya',    bio: null },
  { username: 'zeynep', email: 'zeynep@example.com', phone: '05551110004', fullName: 'Zeynep Sahin',   bio: 'Musait degilim' },
  { username: 'can',    email: 'can@example.com',    phone: '05551110005', fullName: 'Can Ozturk',     bio: null },
];

async function main() {
  console.log('Seed baslatiliyor...');

  await prisma.attachment.deleteMany();
  await prisma.message.deleteMany();
  await prisma.conversationParticipant.deleteMany();
  await prisma.conversation.deleteMany();
  await prisma.block.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.deviceToken.deleteMany();
  await prisma.user.deleteMany();

  const passwordHash = await bcrypt.hash(SEED_PASSWORD, 10);

  const users = {};
  for (const data of USERS) {
    const user = await prisma.user.create({
      data: { ...data, passwordHash },
    });
    users[data.username] = user;
    console.log(`  kullanici: ${user.username}`);
  }

  await createConversation(users.ahmet, users.ayse, [
    { from: 'ahmet',  text: 'Selam, nasilsin?',                minutesAgo: 120 },
    { from: 'ayse',   text: 'Iyiyim sen nasilsin?',            minutesAgo: 118 },
    { from: 'ahmet',  text: 'Ben de iyiyim, tesekkurler',      minutesAgo: 115 },
    { from: 'ayse',   text: 'Yarin musait misin?',             minutesAgo: 30 },
  ]);

  await createConversation(users.ahmet, users.mehmet, [
    { from: 'mehmet', text: 'Proje dosyalarini gonderdin mi?', minutesAgo: 300 },
    { from: 'ahmet',  text: 'Evet, mailine attim',             minutesAgo: 295 },
  ]);

  await createConversation(users.ayse, users.zeynep, [
    { from: 'zeynep', text: 'Toplanti saat kacta?',            minutesAgo: 60 },
  ]);

  console.log('\nSeed tamamlandi.');
  console.log(`Tum kullanicilarin sifresi: ${SEED_PASSWORD}`);
}

async function createConversation(userA, userB, messages) {
  const lastMessageAt = minutesAgoDate(messages[messages.length - 1].minutesAgo);

  const conversation = await prisma.conversation.create({
    data: {
      lastMessageAt,
      participants: {
        create: [
          { userId: userA.id },
          { userId: userB.id },
        ],
      },
    },
  });

  const byUsername = { [userA.username]: userA, [userB.username]: userB };

  for (const msg of messages) {
    const sentAt = minutesAgoDate(msg.minutesAgo);
    await prisma.message.create({
      data: {
        conversationId: conversation.id,
        senderId: byUsername[msg.from].id,
        content: msg.text,
        createdAt: sentAt,
        deliveredAt: new Date(sentAt.getTime() + 2000),
        readAt: msg.minutesAgo > 60 ? new Date(sentAt.getTime() + 60000) : null,
      },
    });
  }

  console.log(`  sohbet: ${userA.username} <-> ${userB.username} (${messages.length} mesaj)`);
}

function minutesAgoDate(minutes) {
  return new Date(Date.now() - minutes * 60 * 1000);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });