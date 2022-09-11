import supabaseAdmin, {saveSite} from '../../supabase/admin'
import {users} from '../../supabase/db'
import { authorizeRequest } from './_auth'
import {publishSite} from './_utils'
import {decode} from 'base64-arraybuffer'

export async function GET(event) {
  return await authorizeRequest(event, async () => {
    const {data} = await supabaseAdmin.storage
      .from('sites')
      .download(`${event.params.site}/site.json?${Date.now()}`)
    const json = JSON.stringify(await data.text())
    return {
      body: json
    }
  })
}

export async function POST(event) {
  return await authorizeRequest(event, async () => {
    const {action, payload} = await event.request.json()

    if (action === 'ADD_USER') {
      // create user (email, password) in auth

      const { data:users } = await supabaseAdmin.from('users').select('*').eq('email', payload.email)
      // const [existingUser] = users.filter(u => u.email === payload.email)
      const [ existingUser ] = users
      if (existingUser) {
        const { error } = await supabaseAdmin.auth.signIn({
          email: payload.email,
          password: payload.password,
        })
        if (!error) {
          await supabaseAdmin.from('users').update({ 
            sites: [ ...existingUser.sites, event.params.site ]
          }).match({ email: payload.email })
        }
      } else {
        const { data: user, error } = await supabaseAdmin.auth.api.createUser({
          email: payload.email,
          password: payload.password,
          email_confirm: true
        })
        if (error) { 
          return { body: false }
        }
        // create user in database for site row and user row, give site permission
        await supabaseAdmin.from('users').insert({ 
          email: payload.email, 
          role: payload.role,
          sites: [event.params.site]
        })
      }

      // reset password
      await supabaseAdmin.from('sites').update({ 
        password: null
      }).match({ id: event.params.site })

      return {
        body: true
      }
    } else if (action === 'REMOVE_USER') {
      // create user (email, password) in auth
      const { error } = await supabaseAdmin.from('users').update({
        sites: payload.sites.filter(s => s !== event.params.site)
      }).match({ email: payload.email })

      if (error) {
        return { body: false }
      }

      return {
        body: 'true'
      }
    } else if (action === 'SET_ACTIVE_EDITOR') {
      await Promise.all([
        supabaseAdmin.from('sites').update({ active_editor: payload.userID }).eq('id', payload.siteID),
        supabaseAdmin.rpc('remove_active_editor', { site: payload.siteID })
      ])
      return {
        body: 'true'
      }
    } else if (action === 'REMOVE_ACTIVE_EDITOR') {
      await supabaseAdmin.from('sites').update({ active_editor: '' }).eq('id', payload.siteID)
      return {
        body: 'true'
      }
    } else if (action === 'UPLOAD_IMAGE') {
      const { siteID, image } = payload
      await supabaseAdmin
        .storage
        .from('sites')
        .upload(`${siteID}/assets/${image.name}`, decode(image.base64), {
          contentType: 'image/png'
        })
  
      const { publicURL } = await supabaseAdmin
        .storage
        .from('sites')
        .getPublicUrl(`${siteID}/assets/${image.name}`)

      return {
        body: publicURL
      }
    }  else if (action === 'SAVE_SITE') {
      const res = await saveSite(payload)
      return {
        body:  res ? 'true' : 'false'
      }
    } else if (action === 'PUBLISH') {
      const { siteID, files, host } = payload
      // get active_deployment from db
      const [{data:hosts}, {data:siteData}] = await Promise.all([
        supabaseAdmin.from('hosts').select('*').eq('name', host.name),
        supabaseAdmin.from('sites').select('*').eq('id', siteID)
      ])
      const [{ active_deployment }] = siteData
      const {deployment, error} = await publishSite({
        siteID: siteID,
        host: hosts[0],
        files,
        activeDeployment: active_deployment
      })
      if (deployment) {
        const {data,error} = await supabaseAdmin.from('sites').update({ 
          active_deployment: deployment
        }).eq('id', siteID)
        if (error) console.error(error)
        return {
          body: {
            deployment,
            error: null
          }
        }
      } else {
        return {
          body: {
            deployment: null,
            error
          }
        }
      }
    } else {
      return {
        body: 'event undefined'
      } 
    }

  })
}

export async function options() {
  return {
    headers: {
			'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,OPTIONS,PATCH,DELETE,POST,PUT',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    }
  }
}