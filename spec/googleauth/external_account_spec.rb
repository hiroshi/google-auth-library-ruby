# Copyright 2023 Google, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'googleauth'
require 'googleauth/apply_auth_examples'
require 'googleauth/external_account'
require 'spec_helper'
require 'tempfile'

describe Google::Auth::ExternalAccount::Credentials do

  describe :make_creds do
    it 'should be able to make aws credentials' do
      f = Tempfile.new('aws')
      begin
        f.write(MultiJson.dump({
          type: 'external_account',
          audience: '//iam.googleapis.com/projects/123456/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID',
          subject_token_type: 'urn:ietf:params:aws:token-type:aws4_request',
          token_url: 'https://sts.googleapis.com/v1/token',
          credential_source: {
            'environment_id' => 'aws1',
            'region_url' => 'http://169.254.169.254/latest/meta-data/placement/availability-zone',
            'url' => 'http://169.254.169.254/latest/meta-data/iam/security-credentials',
            'regional_cred_verification_url' => 'https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15',
          }
        }))
        f.rewind
        expect(Google::Auth::ExternalAccount::Credentials.make_creds(json_key_io: f)).to be_a(Google::Auth::ExternalAccount::AwsCredentials)
      ensure
        f.close
        f.unlink
      end
    end

    [:audience, :subject_token_type, :token_url, :credential_source].each do |field|
      it "should raise an error when missing the #{field} field" do
        f = Tempfile.new('missing')
        begin
          creds = {
            type: 'external_account',
            audience: '//iam.googleapis.com/projects/123456/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID',
            subject_token_type: 'urn:ietf:params:oauth:token-type:id_token',
            token_url: 'https://sts.googleapis.com/v1/token',
            credential_source: {},
          }
          creds.delete(field)
          f.write(MultiJson.dump(creds))
          f.rewind
          expect { Google::Auth::ExternalAccount::Credentials.make_creds(json_key_io: f) }.to raise_error(/the json is missing the #{field} field/)
        ensure
          f.close
          f.unlink
        end
      end
    end

    it 'should raise an error for invalid credentials' do
      f = Tempfile.new('invalid')
      begin
        f.write(MultiJson.dump({
          type: 'external_account',
          audience: '//iam.googleapis.com/projects/123456/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID',
          subject_token_type: 'urn:ietf:params:oauth:token-type:id_token',
          token_url: 'https://sts.googleapis.com/v1/token',
          credential_source: {},
        }))
        f.rewind
        expect { Google::Auth::ExternalAccount::Credentials.make_creds(json_key_io: f) }.to raise_error(/aws is the only currently supported external account type/)
      ensure
        f.close
        f.unlink
      end
    end

    it 'should raise an error if called incorrectly' do
      expect { Google::Auth::ExternalAccount::Credentials.make_creds({
        type: 'external_account',
        audience: '//iam.googleapis.com/projects/123456/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID',
      }) }.to raise_error(/A json file is required for external account credentials./)
    end
  end
end
