
const form = document.querySelector('#message-form');
const statusBox = document.querySelector('#status');
const list = document.querySelector('#messages-list');
const submitButton = document.querySelector('#submit-button');

function setStatus(message, type = 'info') {
  statusBox.textContent = message;
  statusBox.className = message ? `status ${type}` : 'status';
}

async function loadMessages() {
  try {
    const response = await fetch(`${API_BASE_URL}/api/messages`, {
      headers: { Accept: 'application/json' }
    });

    if (!response.ok) {
      throw new Error(`Could not load messages (HTTP ${response.status})`);
    }

    const messages = await response.json();

    if (!Array.isArray(messages)) {
      throw new Error('The API returned an unexpected response.');
    }

    list.replaceChildren();

    if (messages.length === 0) {
      const empty = document.createElement('li');
      empty.className = 'message-empty';
      empty.textContent = 'No messages yet. Be the first to share one!';
      list.append(empty);
      return;
    }

    for (const item of messages) {
      const li = document.createElement('li');
      li.className = 'message-item';

      const avatar = document.createElement('span');
      avatar.className = 'avatar';
      avatar.setAttribute('aria-hidden', 'true');
      avatar.textContent = (item.name || '?').trim().charAt(0).toUpperCase();

      const content = document.createElement('div');
      content.className = 'message-content';

      const name = document.createElement('strong');
      name.textContent = item.name || 'Anonymous';

      const message = document.createElement('p');
      message.textContent = item.message || '';

      content.append(name, message);
      li.append(avatar, content);
      list.append(li);
    }
  } catch (error) {
    const failed = document.createElement('li');
    failed.className = 'message-empty';
    failed.textContent = `${error.message}. Please refresh the page to try again.`;
    list.replaceChildren(failed);
  }
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();

  const name = document.querySelector('#name').value.trim();
  const message = document.querySelector('#message').value.trim();

  if (!name || !message) {
    setStatus('Please enter both your name and a message.', 'error');
    return;
  }

  if (name.length > 100 || message.length > 500) {
    setStatus('Your name must be at most 100 characters and your message at most 500.', 'error');
    return;
  }

  submitButton.disabled = true;
  submitButton.textContent = 'Saving message…';
  setStatus('Sending your message to the API…', 'info');

  try {
    const response = await fetch(`${API_BASE_URL}/api/messages`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json'
      },
      body: JSON.stringify({ name, message })
    });

    const result = await response.json().catch(() => ({}));

    if (!response.ok) {
      throw new Error(result.error || `Could not save message (HTTP ${response.status})`);
    }

    form.reset();
    setStatus('✓ Message saved successfully!', 'success');
    await loadMessages();
  } catch (error) {
    setStatus(
      `${error.message}. Please try again in a moment.`,
      'error'
    );
  } finally {
    submitButton.disabled = false;
    submitButton.innerHTML = '<span aria-hidden="true">➤</span> Save Message';
  }
});

loadMessages();

