<script>
  import { setContext } from 'svelte'
  import '$lib/assets/reset.css'
  import { browser } from '$app/env'
  import { goto } from '$app/navigation'
  import { registerProcessors, dropdown } from '@primo-app/primo'
  import user from '../stores/user'
  import { watchForAutoLogin, signOut } from '../supabase/auth'
  import { users } from '../supabase/db'
  import Modal, { show, hide } from '$lib/components/Modal.svelte'
  import * as actions from '../actions'
  import SiteButtons from '$lib/components/SiteButtons.svelte'

  if (browser) {
    import('../compiler/processors').then(({ html, css }) => {
      registerProcessors({ html, css })
    })
    dropdown.set([
      {
        label: 'Back to Dashboard',
        icon: 'fas fa-arrow-left',
        href: '/',
      },
      {
        component: SiteButtons,
      },
    ])
    setContext('track', () => {})
  }

  watchForAutoLogin(async (event, session) => {
    if (event === 'SIGNED_IN') {
      const { id, email } = session.user
      const [userData] = await users.get(null, 'role, sites', email)
      user.update((u) => ({
        ...u,
        uid: id,
        id,
        email,
        signedIn: true,
        admin: userData.role === 'admin',
        role: userData.role === 'admin' ? 'developer' : userData.role,
        sites: userData.sites,
      }))
    } else if (event === 'SIGNED_OUT') {
      user.reset()
      goto('/')
    } else if (event === 'PASSWORD_RECOVERY') {
      // passwordResetToken = session.access_token;
    } else {
      console.warn('NEW AUTH EVENT', event)
    }
  })

  $: if (!$user.signedIn) {
    show({
      id: 'AUTH',
      options: {
        disableClose: true,
      },
      props: {
        onSignIn: async () => {
          await Promise.all([
            actions.sites.initialize(),
            actions.hosts.initialize(),
          ])
          hide()
        },
      },
    })
  }
</script>

<Modal />
<slot />
