import { fail, redirect } from '@sveltejs/kit';
import { getActiveMemberships, setSelectedOrganization } from '$lib/server/membership';
import { jobIdSchema } from '$lib/validation';
import type { Actions } from './$types';
export const actions: Actions = {
  default: async ({ request, locals, cookies, url }) => {
    const form = await request.formData();
    const id = jobIdSchema.safeParse(form.get('organization_id'));
    if (!id.success) return fail(400, { message: 'Choose a valid organization.' });
    const memberships = await getActiveMemberships(locals);
    if (!memberships.some((membership) => membership.organization_id === id.data))
      return fail(403, { message: 'That organization is not available.' });
    setSelectedOrganization(cookies, id.data, url.protocol === 'https:');
    redirect(303, '/app');
  }
};
