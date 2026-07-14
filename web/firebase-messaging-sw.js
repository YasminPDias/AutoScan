// Service worker do Firebase Messaging — roda fora do Flutter/Dart, então
// precisa da própria cópia da config. Copia os valores do bloco "web" dentro
// do seu lib/firebase_options.dart (gerado pelo flutterfire configure).

importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDFeQ3OTOvFfxsFnLf1b_PyKz1Sxef4gJo',
  authDomain: 'autex-8e341.firebaseapp.com',
  projectId: 'autex-8e341',
  storageBucket: 'autex-8e341.firebasestorage.app',
  messagingSenderId: '171359096707',
  appId: '1:171359096707:web:900992882e26e7b6a230b6',
});

const messaging = firebase.messaging();

// Escuta o evento de push diretamente (em vez do wrapper onBackgroundMessage
// do SDK) e controla o waitUntil() na mão. Isso evita um comportamento
// conhecido do Chrome: se a promise do showNotification() não fica claramente
// conectada ao evento de push a tempo (especialmente quando há trabalho
// assíncrono extra antes de chamar showNotification, como o agrupamento
// abaixo), o Chrome mostra sozinho um aviso genérico de "site atualizado em
// segundo plano" — como se nada tivesse sido exibido de verdade.
self.addEventListener('push', (event) => {
  event.waitUntil(tratarPush(event));
});

async function tratarPush(event) {
  const payload = event.data ? event.data.json() : {};
  const { titulo, corpo, conversaId, tipo } = payload.data || {};

  // mensagem agrupa por conversa (uma notificação por chat); chamado (novo
  // ou disponível) agrupa tudo junto — uma notificação só representando a fila
  const ehMensagem = tipo === 'novaMensagem';
  const tag = ehMensagem ? `chat-${conversaId}` : 'chamados-pendentes';

  const existentes = await self.registration.getNotifications({ tag });
  const contador = existentes.length > 0 ? (existentes[0].data?.contador || 1) + 1 : 1;

  let corpoFinal = corpo || '';
  if (contador > 1) {
    corpoFinal = ehMensagem ? `${contador} novas mensagens` : `${contador} chamados aguardando`;
  }

  return self.registration.showNotification(titulo || 'Nova notificação', {
    body: corpoFinal,
    icon: '/icons/Icon-192.png', // ajusta pro ícone real do seu PWA, se o caminho for outro
    tag,
    renotify: true, // alerta de novo (som/vibração) mesmo substituindo a anterior
    data: { ...payload.data, contador },
  });
}

// clique na notificação — só isso aqui roda quando a aba estava fechada,
// já que nesse caso o código Dart (onMessageOpenedApp/getInitialMessage)
// não está rodando pra capturar o toque
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const conversaId = event.notification.data?.conversaId;
  const urlToOpen = self.location.origin + (conversaId ? `/?conversaId=${conversaId}` : '/');

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) {
          client.navigate(urlToOpen);
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    }),
  );
});